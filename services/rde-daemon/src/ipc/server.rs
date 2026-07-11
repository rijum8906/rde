use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{MessagePayload, Request},
    socket::{IpcClient, IpcServer},
};
use std::sync::Arc;
use tokio::net::UnixStream;

use crate::app::App;

/// IPC supervision server that manages incoming socket connections from client services.
///
/// # SECURITY:
/// - Enforces protocol validation on first message. If the protocol version doesn't match `PROTOCOL_VERSION`,
///   the connection is terminated immediately.
/// - Services are registered by their PID. In the future, verify the PID matches the spawned child PID
///   to prevent pid spoofing/unauthorized registrations.
///
/// # IMPORTANT:
/// - Unregistered clients are logged at debug level and disconnected if they attempt to invoke restricted requests.
///
/// # TODO:
/// - Add heartbeat timeout checking (reap client if no heartbeat is received within timeout).
/// - Implement peer credentials verification (`tokio::net::UnixStream::peer_cred()`) to verify the connecting process
///   uid/gid match the daemon's uid/gid.
pub struct Server {
    pub server: Arc<IpcServer>,
}

impl Server {
    /// Bind the socket and start the listening loop in the background.
    pub fn new() -> RdeResult<Self> {
        let server = Arc::new(IpcServer::new()?);
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

                    // Route payload depending on its category (Request, Response, Event)
                    let result = match msg.payload {
                        MessagePayload::Request(request) => {
                            // Extract and track the service name upon registration
                            if let Request::Register(ref reg) = request {
                                service_name = Some(reg.name.clone());
                            }
                            // Delegate request processing to the request handler module
                            Self::handle_client_request(&mut client, request).await
                        }
                        MessagePayload::Response(response) => {
                            // Delegate response processing to the response handler module
                            Self::handle_client_response(&mut client, response).await
                        }
                        MessagePayload::Event(event) => {
                            // Services do not normally emit unsolicited events to the daemon
                            tracing::warn!(
                                "Received unexpected event notification from client: {:?}",
                                event
                            );
                            Ok(())
                        }
                    };

                    // Close socket if handling encountered an error
                    if let Err(e) = result {
                        tracing::error!(
                            "Error handling message for client {:?}: {}",
                            service_name,
                            e
                        );
                        break;
                    }
                }
                Err(e) => {
                    // Cleanup and remove the client from active registry when connection drops
                    if let Some(ref name) = service_name {
                        tracing::info!("Connection lost or closed for service {}: {}", name, e);
                        app.lock().unwrap().remove_client(name);
                    } else {
                        tracing::debug!("Connection lost or closed for unregistered client: {}", e);
                    }
                    break;
                }
            }
        }
    }
}
