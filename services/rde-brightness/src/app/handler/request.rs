use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{DaemonRequest, ServiceResponse},
    socket::IpcClient,
};

use crate::app::{App, handler::Handler};

impl Handler {
    /// Handle requests pushed by the daemon (e.g. HealthCheck liveness probe).
    pub async fn handle_daemon_request(
        &mut self,
        request: DaemonRequest,
        client: &mut IpcClient,
    ) -> RdeResult<()> {
        match request {
            DaemonRequest::HealthCheck => {
                tracing::debug!(
                    "Received HealthCheck request from daemon, sending Alive response..."
                );
                client.send_service_response(ServiceResponse::Alive).await?;
            }
            DaemonRequest::Shutdown {
                service_name,
                reason,
            } => {
                let mut app_guard = App::global().lock().await;
                app_guard.shutdown().await;
                tracing::info!(
                    "Daemon requested shutdown of service {}: {:?}",
                    service_name,
                    reason
                );
            }
        }
        Ok(())
    }
}
