//! # IPC Supervision Server
//!
//! Binds the supervision socket and runs one asynchronous session task per
//! connected service. Each session validates the protocol version, routes
//! frames to the handlers, and releases the service's registry entry when the
//! connection ends.
//!
//! ## Features
//! - Non-blocking accept loop with a short backoff after transient failures
//! - Per-connection session isolation (a failing service never affects others)
//! - Registry cleanup on disconnect, including half-initialised sessions
//! - Graceful shutdown that stops accepting and removes the socket file
//!
//! ## Related
//! - [`rde_ipc::socket`]: framing and socket primitives
//! - [`crate::handler`]: request and response processing
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{sync::Arc, time::Duration};

use rde_core::errors::{RdeError, RdeResult};
use rde_ipc::{
    message::{MIN_PROTOCOL_VERSION, MessagePayload},
    socket::{IpcClient, IpcServer},
};
use tokio::{net::UnixStream, task::JoinHandle};

use crate::{
    app::App,
    handler::{request::handle_client_request, response::handle_client_response},
};

/// Delay applied after a failed `accept` call to avoid a busy retry loop.
const ACCEPT_ERROR_BACKOFF: Duration = Duration::from_millis(100);

/// Supervision server owning the listening socket and its accept task.
pub struct Server {
    /// Bound listener; held so the socket lives as long as the server.
    listener: Arc<IpcServer>,

    /// Background accept loop, aborted during shutdown.
    accept_task: Option<JoinHandle<()>>,
}

impl Server {
    /// Binds the supervision socket and starts accepting connections.
    ///
    /// # Errors
    /// Returns an error if the socket path cannot be resolved or the socket
    /// cannot be bound (for example when another daemon instance is running).
    ///
    /// # Returns
    /// A running [`Server`] whose accept loop is already scheduled.
    pub fn new() -> RdeResult<Self> {
        Self::from_listener(IpcServer::new()?)
    }

    /// Binds a supervision socket at an explicit path.
    ///
    /// Used by tests and by tooling that hosts the supervisor on a private
    /// socket. Production callers should use [`Server::new`].
    ///
    /// # Parameters
    /// - `socket_path`: path of the Unix socket file to bind
    ///
    /// # Errors
    /// Returns an error if the socket cannot be bound.
    pub fn new_with_path(socket_path: std::path::PathBuf) -> RdeResult<Self> {
        let listener = IpcServer::new_with_path(socket_path)
            .map_err(|error| RdeError::Socket(error.to_string()))?;
        Self::from_listener(listener)
    }

    /// Starts the accept loop for an already bound listener.
    fn from_listener(listener: IpcServer) -> RdeResult<Self> {
        // 1. Keep the listener alive for the server's lifetime.
        let listener = Arc::new(listener);
        tracing::info!(
            socket = %listener.socket_path().display(),
            "IPC supervision server listening"
        );

        // 2. Serve connections in the background; each connection gets its own task.
        let accept_listener = Arc::clone(&listener);
        let accept_task = tokio::spawn(async move { Self::accept_loop(accept_listener).await });

        Ok(Self {
            listener,
            accept_task: Some(accept_task),
        })
    }

    /// Returns the socket path the server is listening on.
    pub fn socket_path(&self) -> &std::path::Path {
        self.listener.socket_path().as_path()
    }

    /// Accepts connections until the task is aborted.
    ///
    /// Transient accept failures are logged and retried after
    /// [`ACCEPT_ERROR_BACKOFF`] so the loop never spins on a persistent error.
    async fn accept_loop(listener: Arc<IpcServer>) {
        loop {
            match listener.accept().await {
                Ok(stream) => {
                    tokio::spawn(async move {
                        if let Err(error) = Self::handle_client(stream).await {
                            tracing::warn!(%error, "Service session ended with an error");
                        }
                    });
                }
                Err(error) => {
                    tracing::error!(%error, "Failed to accept client connection");
                    tokio::time::sleep(ACCEPT_ERROR_BACKOFF).await;
                }
            }
        }
    }

    /// Runs the message loop for a single connected service.
    ///
    /// # Parameters
    /// - `stream`: the accepted connection to the service
    ///
    /// # Errors
    /// Returns an error if the daemon state cannot be locked or a registration
    /// acknowledgement cannot be delivered. A closed socket ends the session
    /// cleanly and is not treated as an error.
    ///
    /// # Cleanup
    /// Any service registered on this connection is removed from the registry
    /// before the function returns, whichever way the session ended.
    pub async fn handle_client(stream: UnixStream) -> RdeResult<()> {
        let mut client = IpcClient::from(stream);
        let mut registered_service: Option<String> = None;

        loop {
            // 1. Read the next frame. A closed socket is an expected end of the
            //    session, not an error worth failing the daemon over.
            let message = match client.recv().await {
                Ok(message) => message,
                Err(error) => {
                    tracing::debug!(
                        service = registered_service.as_deref().unwrap_or("unregistered"),
                        %error,
                        "Service connection closed"
                    );
                    break;
                }
            };

            // 2. Reject incompatible peers before touching any daemon state.
            if !message.is_protocol_supported() {
                tracing::warn!(
                    protocol_version = message.protocol_version,
                    min_supported = MIN_PROTOCOL_VERSION,
                    "Rejected service using an unsupported protocol version"
                );
                break;
            }

            // 3. Route the payload and stop the session if handling fails.
            let result = match message.payload {
                MessagePayload::ServiceRequest(request) => {
                    handle_client_request(&mut client, request, &mut registered_service).await
                }
                MessagePayload::ServiceResponse(response) => {
                    handle_client_response(response);
                    Ok(())
                }
                other => {
                    tracing::warn!(
                        payload = ?other,
                        "Ignoring unexpected message payload from service"
                    );
                    Ok(())
                }
            };

            if let Err(error) = result {
                tracing::error!(
                    service = registered_service.as_deref().unwrap_or("unregistered"),
                    %error,
                    "Failed to process service message"
                );
                break;
            }
        }

        // 4. Release the registry entry so a later reconnection starts clean.
        if let Some(service_name) = registered_service {
            let removed = App::with_global(|app| app.deregister(&service_name))?;
            if removed.is_some() {
                tracing::info!(
                    service = %service_name,
                    "Service removed from registry after disconnect"
                );
            }
        }

        Ok(())
    }

    /// Stops accepting connections and removes the socket file.
    ///
    /// Consumes the server so it cannot be used after shutdown.
    ///
    /// # Errors
    /// Returns an error if the socket file cannot be removed.
    pub fn shutdown(mut self) -> RdeResult<()> {
        // 1. Stop the accept loop before releasing the socket.
        if let Some(accept_task) = self.accept_task.take() {
            accept_task.abort();
        }

        // 2. Remove the socket file so a restart can bind the same path.
        self.listener.shutdown()?;
        tracing::info!("IPC supervision server stopped");

        Ok(())
    }
}
