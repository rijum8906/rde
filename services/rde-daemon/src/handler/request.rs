//! # Service Request Handler
//!
//! Processes [`ServiceRequest`] messages sent by supervised services over the
//! supervision socket: registration, deregistration, and status updates.
//!
//! ## Request Types
//! - `Register`: adds the service to the daemon registry and replies with `RegisterAck`
//! - `Deregister`: removes the service from the daemon registry
//! - `StatusUpdate`: refreshes the status of an already registered service
//!
//! ## Related
//! - [`rde_ipc::message::request`]: request payload definitions
//! - [`crate::app::App`]: registry mutated by these handlers
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::time::SystemTime;

use rde_core::errors::{RdeError, RdeResult};
use rde_ipc::{
    message::{AckResponse, DaemonResponse, ServiceId, ServiceInfo, ServiceRequest, ServiceStatus},
    socket::IpcClient,
};

use crate::app::App;

/// Handles a single request from a connected service.
///
/// # Parameters
/// - `client`: the connection the request arrived on, used to send acknowledgements
/// - `request`: the decoded request payload
/// - `registered_service`: name this connection is registered under, updated on `Register`
///
/// # Errors
/// Returns an error when the daemon state cannot be locked, when the
/// registration acknowledgement cannot be delivered, or when a protocol write
/// to the client fails. The caller treats any error as a reason to close the
/// connection and clean up the session.
pub async fn handle_client_request(
    client: &mut IpcClient,
    request: ServiceRequest,
    registered_service: &mut Option<String>,
) -> RdeResult<()> {
    match request {
        ServiceRequest::Register(registration) => {
            // 1. Track the service name for the lifetime of this connection so
            //    status updates and disconnect cleanup can address the entry.
            *registered_service = Some(registration.name.clone());

            // 2. Build the registry entry. `uptime` holds the registration
            //    timestamp; the daemon does not report elapsed time per service.
            let service = ServiceInfo {
                id: ServiceId {
                    name: registration.name.clone(),
                    pid: registration.pid,
                },
                status: ServiceStatus::Running,
                uptime: Some(SystemTime::now()),
                restart_count: 0,
                version: registration.version.clone(),
            };

            // 3. Insert the entry, reporting any stale entry that it replaced.
            let replaced = App::with_global(|app| app.register(service))?;
            if let Some(previous) = replaced {
                tracing::warn!(
                    service = %registration.name,
                    previous_pid = previous.id.pid,
                    pid = registration.pid,
                    "Service re-registered, replacing previous entry"
                );
            }

            tracing::info!(
                service = %registration.name,
                pid = registration.pid,
                version = %registration.version,
                capabilities = ?registration.capabilities,
                registered_services = App::with_global(|app| app.service_count())?,
                "Service registered"
            );

            // 4. Acknowledge registration so the service can start its work.
            client
                .send_daemon_response(DaemonResponse::RegisterAck(AckResponse {
                    success: true,
                    reason: None,
                }))
                .await
                .map_err(|error| RdeError::Socket(error.to_string()))?;
        }

        ServiceRequest::Deregister { pid, name } => {
            let removed = App::with_global(|app| app.deregister(&name))?;

            if removed.is_some() {
                tracing::info!(service = %name, pid, "Service deregistered");
            } else {
                tracing::warn!(
                    service = %name,
                    pid,
                    "Deregistration ignored, service was not registered"
                );
            }

            // The connection no longer owns a registry entry.
            if registered_service.as_deref() == Some(name.as_str()) {
                *registered_service = None;
            }
        }

        ServiceRequest::StatusUpdate(update) => {
            // 1. Reject updates from connections that never registered.
            let Some(service_name) = registered_service.clone() else {
                tracing::warn!(
                    status = ?update.status,
                    "Ignoring status update from unregistered connection"
                );
                return Ok(());
            };

            // 2. Apply the transition, warning if the registry entry vanished.
            let updated =
                App::with_global(|app| app.update_status(&service_name, update.status.clone()))?;

            if updated {
                tracing::info!(
                    service = %service_name,
                    status = ?update.status,
                    message = update.message.as_deref().unwrap_or_default(),
                    "Service status updated"
                );
            } else {
                tracing::warn!(
                    service = %service_name,
                    status = ?update.status,
                    "Status update ignored, service is not registered"
                );
            }
        }
    }

    Ok(())
}
