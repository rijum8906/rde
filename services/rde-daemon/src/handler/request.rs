use std::time::SystemTime;

use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{Request, Response, ServiceId, ServiceInfo, ServiceStatus},
    socket::IpcClient,
};

use crate::{app::App, ipc::server::Server};

impl Server {
    pub async fn handle_client_request(client: &mut IpcClient, request: Request) -> RdeResult<()> {
        let app = App::global();

        match request {
            Request::Register(register_request) => {
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
                let response = Response::register_ack(
                    true,
                    "Registered successfully",
                    &format!("{}-{}", register_request.name, register_request.pid),
                );
                if let Err(e) = client.send_response(response).await {
                    tracing::error!(
                        "Failed to send RegisterAck to client {}: {}",
                        register_request.name,
                        e
                    );
                    return Err(e);
                }
            }
            Request::Heartbeat(_heartbeat_request) => todo!(),
            Request::GetStatus(_get_status_request) => todo!(),
            Request::ListServices(_list_services_request) => todo!(),
            Request::Shutdown(_shutdown_request) => todo!(),
            Request::StatusUpdate(_status_update_request) => todo!(),
        }

        Ok(())
    }
}
