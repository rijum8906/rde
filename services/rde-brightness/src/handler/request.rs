//! # Supervisor Request Handler (`rde-brightness`)
//!
//! Answers requests pushed by the `rde-daemon` supervisor.
//!
//! ## Request Types
//! - `HealthCheck`: liveness probe answered with `Alive`
//! - `GetStatus`: reports whether the event loop is running
//! - `Shutdown`: requests cooperative shutdown of the service
//!
//! ## Related
//! - [`crate::app::App`][]: owns the reported status and shutdown token
//! - [`crate::handler::handle_message`][]: caller
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::errors::{RdeError, RdeResult};
use rde_ipc::{
    error::IpcError,
    message::{DaemonRequest, ServiceResponse},
    socket::IpcClient,
};
use tracing::{debug, info, warn};

use crate::handler::SupervisionContext;

/// Handles a request from the supervisor.
///
/// # Parameters
/// - `request`: decoded supervisor request
/// - `client`: connection used to answer the supervisor
/// - `context`: lock-free view of the application runtime state
///
/// # Workflow
/// 1. `HealthCheck`: reply immediately with `Alive`
/// 2. `GetStatus`: read the runtime status and reply with it
/// 3. `Shutdown`: request cooperative shutdown without blocking the caller
///
/// # Errors
/// Returns [`RdeError::Socket`] when a response cannot be written.
pub async fn handle_daemon_request(
    request: DaemonRequest,
    client: &mut IpcClient,
    context: &SupervisionContext,
) -> RdeResult<()> {
    match request {
        DaemonRequest::HealthCheck => {
            debug!("Received health check probe from the supervisor");

            client
                .send_service_response(ServiceResponse::Alive)
                .await
                .map_err(socket_error)?;

            debug!("Replied to the health check probe");
        }

        DaemonRequest::GetStatus(query) => {
            // Step 1: Read the current runtime status.
            let status = context.status();

            // Step 2: Report it back to the supervisor.
            debug!(service = %query.name, ?status, "Reporting service status");
            client
                .send_service_response(ServiceResponse::Status(status))
                .await
                .map_err(socket_error)?;
        }

        DaemonRequest::Shutdown {
            service_name,
            reason,
        } => {
            info!(
                service = %service_name,
                reason = reason.as_deref().unwrap_or("unspecified"),
                "Shutdown requested by the supervisor"
            );

            // Only signal the request here: `App::shutdown` waits for this very
            // supervision task to finish, which would deadlock if called inline.
            context.request_shutdown();
        }
    }

    Ok(())
}

/// Converts an IPC failure into a domain socket error.
fn socket_error(error: IpcError) -> RdeError {
    warn!(%error, "Failed to write to the supervision socket");
    RdeError::Socket(error.to_string())
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, atomic::AtomicBool};

    use rde_ipc::message::{GetStatusRequest, MessagePayload, ServiceStatus};
    use tokio::net::UnixStream;
    use tokio_util::sync::CancellationToken;

    use super::*;

    /// Builds a connected client pair backed by an in-memory socket.
    fn client_pair() -> (IpcClient, IpcClient) {
        let (service_side, daemon_side) = UnixStream::pair().expect("in-memory socket pair");
        (IpcClient::from(service_side), IpcClient::from(daemon_side))
    }

    /// Builds a context with the given running state.
    fn context(running: bool, shutdown: CancellationToken) -> SupervisionContext {
        SupervisionContext::new(Arc::new(AtomicBool::new(running)), shutdown)
    }

    #[tokio::test]
    async fn answers_health_check_with_alive() {
        let (mut client, mut daemon) = client_pair();

        handle_daemon_request(
            DaemonRequest::HealthCheck,
            &mut client,
            &context(true, CancellationToken::new()),
        )
        .await
        .expect("health check must be answered");

        let response = daemon.recv().await.expect("response frame");
        assert!(
            matches!(
                response.payload,
                MessagePayload::ServiceResponse(ServiceResponse::Alive)
            ),
            "health check must be answered with Alive"
        );
    }

    #[tokio::test]
    async fn reports_running_and_stopped_status() {
        for (running, expected) in [
            (true, ServiceStatus::Running),
            (false, ServiceStatus::Stopped),
        ] {
            let (mut client, mut daemon) = client_pair();
            let query = DaemonRequest::GetStatus(GetStatusRequest {
                name: "brightness".to_string(),
            });

            handle_daemon_request(
                query,
                &mut client,
                &context(running, CancellationToken::new()),
            )
            .await
            .expect("status query must be answered");

            let response = daemon.recv().await.expect("response frame");
            match response.payload {
                MessagePayload::ServiceResponse(ServiceResponse::Status(status)) => {
                    assert_eq!(status, expected);
                }
                other => panic!("unexpected response payload: {other:?}"),
            }
        }
    }

    #[tokio::test]
    async fn shutdown_request_cancels_the_event_loop() {
        let (mut client, _daemon) = client_pair();
        let token = CancellationToken::new();

        handle_daemon_request(
            DaemonRequest::Shutdown {
                service_name: "brightness".to_string(),
                reason: Some("test".to_string()),
            },
            &mut client,
            &context(true, token.clone()),
        )
        .await
        .expect("shutdown request must be accepted");

        assert!(token.is_cancelled(), "shutdown token must be cancelled");
    }
}
