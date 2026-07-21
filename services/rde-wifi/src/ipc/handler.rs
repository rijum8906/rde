use std::sync::Arc;

use futures_util::lock::Mutex;
use rde_core::{errors::RdeResult, utils::ipc::get_socket_path};
use rde_ipc::{message::DaemonRequest, socket::IpcClient};

pub struct IpcHandler {
    pub client: Arc<Mutex<IpcClient>>,
}

impl IpcHandler {
    /// Connect to the ipc daemon socket
    pub async fn connect() -> RdeResult<Self> {
        let socket_path = get_socket_path()?;
        let client = IpcClient::connect(&socket_path).await?;

        Ok(Self {
            client: Arc::new(Mutex::new(client)),
        })
    }

    /// spawns a thread to handle the ipc communication
    pub async fn spawn_ipc_message_handler(&mut self) -> tokio::task::JoinHandle<()> {
        let client = self.client.clone();
        tokio::spawn(async move {
            // Send registration request first
            let version = env!("CARGO_PKG_VERSION").to_string();
            let register_msg =
                rde_ipc::message::Message::new(rde_ipc::message::MessagePayload::ServiceRequest(
                    rde_ipc::message::ServiceRequest::Register(rde_ipc::message::RegisterRequest {
                        pid: std::process::id(),
                        name: "wifi".to_string(),
                        version,
                        capabilities: vec![],
                    }),
                ));

            {
                let mut client_guard = client.lock().await;
                if let Err(e) = client_guard.send(&register_msg).await {
                    tracing::error!("Failed to send registration request: {}", e);
                    return;
                }
            }

            loop {
                // Lock client only to call recv()
                let mut client_guard = client.lock().await;
                let msg = match client_guard.recv().await {
                    Ok(m) => m,
                    Err(e) => {
                        tracing::error!("Failed to receive ipc message: {}", e);
                        continue;
                    }
                };

                let _client_clone = client.clone();

                match msg.payload {
                    rde_ipc::message::MessagePayload::DaemonRequest(daemon_request) => {
                        if let Err(e) =
                            IpcHandler::handle_daemon_request(daemon_request, &mut client_guard)
                                .await
                        {
                            tracing::error!("Error handling daemon request: {}", e);
                        }
                    }
                    rde_ipc::message::MessagePayload::DaemonResponse(daemon_response) => {
                        if let Err(e) =
                            IpcHandler::handle_daemon_response(daemon_response, &mut client_guard)
                                .await
                        {
                            tracing::error!("Error handling daemon response: {}", e);
                        }
                    }
                    _ => {
                        tracing::warn!(
                            "Service received unexpected payload category from daemon: {:?}",
                            msg.payload
                        );
                    }
                };
            }
        })
    }

    pub async fn shutdown(&mut self) -> RdeResult<()> {
        // send shutdown request to daemon
        self.client
            .lock()
            .await
            .send_daemon_request(DaemonRequest::Shutdown {
                service_name: "wifi".to_string(),
                reason: Some("Some reason".to_string()),
            })
            .await?;

        // close the ipc client
        self.client.lock().await.close().await
    }
}
