use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{DaemonRequest, ServiceResponse, ServiceStatus},
    socket::IpcClient,
};

use crate::{app::Application, ipc::handler::IpcHandler};

impl IpcHandler {
    /// Handle requests pushed by the daemon (e.g. HealthCheck liveness probe).
    pub async fn handle_daemon_request(
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
            DaemonRequest::GetStatus(req) => {
                tracing::debug!("Received GetStatus request from daemon for {}", req.name);
                let is_running = Application::global().await.lock().await.is_running();
                let status = if is_running {
                    ServiceStatus::Running
                } else {
                    ServiceStatus::Stopped
                };
                client
                    .send_service_response(ServiceResponse::Status(status))
                    .await?;
            }
            DaemonRequest::Shutdown {
                service_name,
                reason,
            } => {
                let mut app_guard = Application::global().await.lock().await;
                app_guard.shutdown().await?;
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
