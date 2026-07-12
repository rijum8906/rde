use std::time::SystemTime;

use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{AckResponse, DaemonResponse, ServiceId, ServiceInfo, ServiceRequest, ServiceStatus},
    socket::IpcClient,
};

use crate::{app::App, ipc::server::Server};

impl Server {
    /// Process incoming requests from supervised client services.
    pub async fn handle_client_request(
        client: &mut IpcClient,
        request: ServiceRequest,
        service_name: &Option<String>,
    ) -> RdeResult<()> {
        let app = App::global();

        match request {
            ServiceRequest::Register(register_request) => {
                tracing::info!(
                    "Registering service: {} (PID: {}, Version: {})",
                    register_request.name,
                    register_request.pid,
                    register_request.version
                );

                let service_info = ServiceInfo {
                    id: ServiceId {
                        name: register_request.name.clone(),
                        pid: register_request.pid,
                    },
                    status: ServiceStatus::Running,
                    uptime: Some(SystemTime::now()),
                    restart_count: 0,
                    version: register_request.version.clone(),
                };

                app.lock().unwrap().add_client(service_info);

                // Send back RegisterAck response
                let response = DaemonResponse::RegisterAck(AckResponse {
                    success: true,
                    reason: None,
                });
                if let Err(e) = client.send_daemon_response(response).await {
                    tracing::error!(
                        "Failed to send RegisterAck to client {}: {}",
                        register_request.name,
                        e
                    );
                    return Err(e);
                }
            }
            ServiceRequest::Deregister { pid, name } => {
                tracing::info!("Deregistering service {} (PID: {})", name, pid);
                app.lock().unwrap().remove_client(&name);
            }
            ServiceRequest::StatusUpdate(status_update_request) => {
                if let Some(name) = service_name {
                    tracing::info!(
                        "Received StatusUpdate request from service {}: {:?}",
                        name,
                        status_update_request.status
                    );
                    let mut app_lock = app.lock().unwrap();
                    if let Some(client_info) =
                        app_lock.clients.iter_mut().find(|c| &c.id.name == name)
                    {
                        client_info.status = status_update_request.status;
                    }
                } else {
                    tracing::warn!("Received StatusUpdate request from unregistered client");
                }
            }
        }

        Ok(())
    }
}
