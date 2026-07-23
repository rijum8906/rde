//! # IPC Client & Message Loop Handler
//!
//! Manages connection creation, service registration handshakes, incoming message listening loops,
//! and graceful disconnect operations for communicating with the `rde-daemon` supervisor.
//!
//! ## Features
//! - Thread-safe `IpcClient` socket handle creation via Unix domain socket
//! - Registration handshake (`RegisterRequest`) with `rde-daemon` supervisor
//! - Asynchronous message routing loop for incoming IPC messages
//!
//! ## Related
//! - [`crate::ipc::daemon_request`]
//! - [`crate::ipc::daemon_response`]
//! - [`rde_ipc::socket::IpcClient`](rde_ipc::socket::IpcClient)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::sync::Arc;

use futures_util::lock::Mutex;
use rde_core::{errors::RdeResult, utils::ipc::get_socket_path};
use rde_ipc::{message::DaemonRequest, socket::IpcClient};

/// Wrapper around a thread-safe reference-counted `IpcClient` socket connection.
pub struct IpcHandler {
    /// Arc-Mutex protected `IpcClient` for concurrent socket operations.
    pub client: Arc<Mutex<IpcClient>>,
}

impl IpcHandler {
    /// Connects to the system IPC daemon socket path.
    ///
    /// # Errors
    /// Returns `RdeError` if resolving socket path or establishing connection fails.
    pub async fn connect() -> RdeResult<Self> {
        let socket_path = get_socket_path()?;
        let client = IpcClient::connect(&socket_path).await?;

        Ok(Self {
            client: Arc::new(Mutex::new(client)),
        })
    }

    /// Spawns an asynchronous Tokio background task to handle registration handshake and IPC message dispatching.
    ///
    /// # Workflow
    /// 1. Sends `RegisterRequest` with service name `"wifi"` and package version to `rde-daemon`.
    /// 2. Enters a loop receiving `MessagePayload` objects from the socket.
    /// 3. Routes `DaemonRequest` messages to `handle_daemon_request` and `DaemonResponse` messages to `handle_daemon_response`.
    ///
    /// # Returns
    /// Tokio `JoinHandle<()>` for managing task lifecycle.
    pub async fn spawn_ipc_message_handler(&mut self) -> tokio::task::JoinHandle<()> {
        let client = self.client.clone();
        tokio::spawn(async move {
            // Step 1: Send service registration handshake request first
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

            // Step 2: Main IPC message processing loop
            loop {
                // Lock socket client to acquire the next message frame
                let mut client_guard = client.lock().await;
                let msg = match client_guard.recv().await {
                    Ok(m) => m,
                    Err(e) => {
                        tracing::error!("Failed to receive ipc message: {}", e);
                        continue;
                    }
                };

                let _client_clone = client.clone();

                // Route message payload to appropriate handler implementation
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

    /// Sends a shutdown request to the supervisor daemon and closes the underlying socket.
    ///
    /// # Errors
    /// Returns `RdeError` if sending shutdown message or socket close operation fails.
    pub async fn shutdown(&mut self) -> RdeResult<()> {
        // Send shutdown request to supervisor daemon
        self.client
            .lock()
            .await
            .send_daemon_request(DaemonRequest::Shutdown {
                service_name: "wifi".to_string(),
                reason: Some("Service process shutting down".to_string()),
            })
            .await?;

        // Close the underlying IPC socket connection
        self.client.lock().await.close().await
    }
}
