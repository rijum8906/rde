use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{MessagePayload, ServiceRequest},
    socket::{IpcClient, IpcServer},
};
use std::sync::Arc;
use tokio::net::UnixStream;

use crate::app::App;

/// IPC supervision server that manages incoming socket connections from client services.
pub struct Server {
    pub server: Arc<IpcServer>,
}

impl Server {
    /// Bind the socket and start the listening loop in the background.
    pub fn new() -> RdeResult<Self> {
        // Initialize log directory and Logger for IPC
        let base_log_dir = rde_core::utils::logger::init_log_dir()?;
        let log_dir = base_log_dir.join("daemon-ipc");
        let logger =
            rde_core::logger::Logger::new(rde_core::logger::LogLevel::Info, log_dir, "daemon-ipc");

        let server = Arc::new(IpcServer::new(logger)?);
        let server_clone = Arc::clone(&server);

        // Spawn a background task to accept incoming client connections
        tokio::spawn(async move {
            loop {
                match server_clone.accept().await {
                    Ok(client) => {
                        tokio::spawn(Self::handle_client(client));
                    }
                    Err(e) => {
                        tracing::error!("Error accepting client connection: {}", e);
                    }
                }
            }
        });

        Ok(Self { server })
    }

    /// Read and route messages from a connected client stream asynchronously.
    pub async fn handle_client(stream: UnixStream) {
        let mut client = IpcClient::new(stream);
        let app = App::global();
        let mut service_name: Option<String> = None;

        loop {
            match client.recv().await {
                Ok(msg) => {
                    // Verify that the client is using a compatible protocol version
                    if !msg.is_protocol_supported() {
                        tracing::warn!(
                            "Rejected client: unsupported protocol version {}",
                            msg.protocol_version
                        );
                        break;
                    }

                    // Route payload depending on its category (ServiceRequest or ServiceResponse)
                    let result = match msg.payload {
                        MessagePayload::ServiceRequest(request) => {
                            // Extract and track the service name upon registration
                            if let ServiceRequest::Register(ref reg) = request {
                                service_name = Some(reg.name.clone());
                            }
                            // Delegate request processing to the request handler module
                            Self::handle_client_request(&mut client, request, &service_name).await
                        }
                        MessagePayload::ServiceResponse(response) => {
                            // Delegate response processing to the response handler module
                            Self::handle_client_response(&mut client, response).await
                        }
                        _ => {
                            tracing::warn!(
                                "Received unexpected message payload category from client: {:?}",
                                msg.payload
                            );
                            Ok(())
                        }
                    };

                    if let Err(e) = result {
                        tracing::error!(
                            "Error handling client message (Service: {:?}): {}",
                            service_name,
                            e
                        );
                        break;
                    }
                }
                Err(e) => {
                    tracing::debug!(
                        "Client connection closed (Service: {:?}): {}",
                        service_name,
                        e
                    );
                    break;
                }
            }
        }

        // Clean up: remove the client from the active registry if it was registered
        if let Some(ref name) = service_name {
            tracing::info!("Cleaning up disconnected service: {}", name);
            let mut app_lock = app.lock().unwrap();
            app_lock.remove_client(name);
        }
    }
}
