//! # Daemon Request Handler Module
//!
//! Processes incoming IPC requests pushed by the `rde-daemon` supervisor process.
//!
//! ## Features
//! - `HealthCheck` request handling (liveness ping response)
//! - `GetStatus` status query resolution
//! - Graceful `Shutdown` request execution
//! - Comprehensive logging of all request types
//!
//! ## Related
//! - [`crate::ipc::handler::IpcHandler`]
//! - [`crate::app::Application`]
//! - [`rde_ipc::message::DaemonRequest`](rde_ipc::message::DaemonRequest)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{DaemonRequest, ServiceResponse, ServiceStatus},
    socket::IpcClient,
};

use crate::{app::Application, ipc::handler::IpcHandler};

impl IpcHandler {
    /// Handles requests pushed by the supervisor daemon (e.g., `HealthCheck` liveness probes, `GetStatus`, `Shutdown`).
    ///
    /// # Parameters
    /// - `request`: The incoming `DaemonRequest` payload from the supervisor.
    /// - `client`: Active `IpcClient` socket connection for transmitting responses back.
    ///
    /// # Request Types
    /// - **HealthCheck**: Responds with `Alive` status to confirm service liveness
    /// - **GetStatus**: Returns current service state (Running/Stopped)
    /// - **Shutdown**: Gracefully terminates the service
    ///
    /// # Errors
    /// Returns `RdeError` if sending the response over the IPC socket fails.
    pub async fn handle_daemon_request(
        request: DaemonRequest,
        client: &mut IpcClient,
    ) -> RdeResult<()> {
        match request {
            // Liveness ping from daemon supervisor
            DaemonRequest::HealthCheck => {
                tracing::debug!("Received HealthCheck liveness probe from daemon");
                client.send_service_response(ServiceResponse::Alive).await?;
                tracing::debug!("Sent Alive response to daemon health check");
            }
            // Status query from daemon supervisor
            DaemonRequest::GetStatus(req) => {
                tracing::debug!(
                    "Received GetStatus request from daemon for service: {}",
                    req.name
                );
                let is_running = Application::global().await.lock().await.is_running();
                let status = if is_running {
                    ServiceStatus::Running
                } else {
                    ServiceStatus::Stopped
                };
                tracing::debug!("Theme service status: {:?}", status);
                client
                    .send_service_response(ServiceResponse::Status(status))
                    .await?;
            }
            // Graceful shutdown instruction from daemon supervisor
            DaemonRequest::Shutdown {
                service_name,
                reason,
            } => {
                tracing::warn!(
                    "Received shutdown request from daemon for service '{}': {:?}",
                    service_name,
                    reason
                );
                let mut app_guard = Application::global().await.lock().await;
                app_guard.shutdown().await?;
                tracing::info!("Service shutdown completed following daemon request");
            }
        }
        Ok(())
    }
}
