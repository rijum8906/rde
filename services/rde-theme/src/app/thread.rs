//! # Daemon Supervision Task (`rde-theme`)
//!
//! Connects to the `rde-daemon` supervision socket, registers the service,
//! routes incoming daemon messages, and deregisters on disconnect.
//!
//! ## Features
//! - Connection attempts with a bounded retry policy
//! - `Register` / `Deregister` handshake using the shared `rde-ipc` protocol
//! - Cooperative cancellation through the application shutdown token
//! - Message dispatch delegated to [`crate::handler`]
//!
//! ## Related
//! - [`crate::app::App::spawn_daemon_thread`][]: spawns this task
//! - [`crate::handler::handle_message`][]: message routing
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{
    path::PathBuf,
    process,
    sync::{Arc, atomic::Ordering},
    time::Duration,
};

use rde_core::{
    errors::{RdeError, RdeResult},
    utils::ipc::get_socket_path,
};
use rde_ipc::{
    IpcCommand,
    message::{RegisterRequest, ServiceRequest},
    socket::IpcClient,
    thread::IpcThread,
};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

use crate::{
    app::App,
    constants::{
        CAPABILITIES, MAX_SOCKET_CONN_RETRY_COUNT, SERVICE_NAME, SOCKET_CONN_RETRY_DELAY_MS,
    },
    handler::{SupervisionContext, handle_message},
};

impl App {
    /// Spawns the daemon supervision task and stores its handle.
    ///
    /// # Workflow
    /// 1. Create the command channel and cancellation token owned by [`App`]
    /// 2. Resolve the daemon socket path inside the task
    /// 3. Connect with retry, then register the service
    /// 4. Serve messages until cancelled, asked to stop, or the socket dies
    /// 5. Deregister on the way out so the registry is not left stale
    pub fn spawn_daemon_thread(&mut self) {
        let (tx, mut rx) = mpsc::channel::<IpcCommand>(4);
        let cancellation_token = CancellationToken::new();
        let task_token = cancellation_token.clone();
        let version = self.version.clone();
        let connected = Arc::clone(&self.connected);
        let context =
            SupervisionContext::new(Arc::clone(&self.is_running), self.shutdown_token.clone());

        debug!("Spawning daemon supervision task");

        let handle = tokio::spawn(async move {
            // Step 1: Resolve the socket path; supervision is optional, so a
            // failure here only disables supervision rather than the service.
            let socket_path = match get_socket_path() {
                Ok(path) => path,
                Err(error) => {
                    error!(%error, "Unable to resolve the daemon socket path");
                    return;
                }
            };

            // Step 2: Connect with the shared retry policy.
            let mut client = IpcClient::default();
            if !connect(&mut client, &socket_path).await {
                error!(
                    attempts = MAX_SOCKET_CONN_RETRY_COUNT,
                    "Giving up on daemon supervision, service continues unsupervised"
                );
                return;
            }
            connected.store(true, Ordering::Relaxed);

            // Step 3: Announce the service to the supervisor.
            match register(&mut client, &version).await {
                Ok(()) => info!(
                    service = SERVICE_NAME,
                    "Service registered with the supervisor"
                ),
                Err(error) => {
                    warn!(%error, "Registration failed, service continues unsupervised");
                }
            }

            // Step 4: Serve messages until one of the exit conditions is met.
            let reason = loop {
                tokio::select! {
                    _ = task_token.cancelled() => break "cancellation requested",
                    command = rx.recv() => match command {
                        Some(IpcCommand::Shutdown) => break "shutdown command received",
                        None => break "command channel closed",
                    },
                    received = client.recv() => match received {
                        Ok(message) => {
                            if let Err(error) =
                                handle_message(message, &mut client, &context).await
                            {
                                warn!(%error, "Daemon message handling failed");
                                break "message handling failed";
                            }
                        }
                        Err(error) => {
                            warn!(%error, "Supervision socket closed");
                            break "socket closed";
                        }
                    },
                }
            };

            debug!(reason, "Supervision loop stopped");
            connected.store(false, Ordering::Relaxed);

            // Step 5: Best-effort cleanup so the supervisor drops the entry now.
            if let Err(error) = deregister(&mut client).await {
                debug!(%error, "Could not tell the supervisor about the disconnect");
            }
        });

        self.ipc_thread = Some(IpcThread {
            tx,
            handle,
            cancellation_token,
        });
    }
}

/// Connects to the supervision socket, retrying with a fixed delay.
///
/// # Returns
/// `true` when a connection was established, `false` after the final attempt.
async fn connect(client: &mut IpcClient, socket_path: &PathBuf) -> bool {
    for attempt in 1..=MAX_SOCKET_CONN_RETRY_COUNT {
        match client.connect(socket_path).await {
            Ok(()) => {
                info!(
                    attempt,
                    max_attempts = MAX_SOCKET_CONN_RETRY_COUNT,
                    path = %socket_path.display(),
                    "Connected to the supervision socket"
                );
                return true;
            }
            Err(error) => {
                warn!(
                    attempt,
                    max_attempts = MAX_SOCKET_CONN_RETRY_COUNT,
                    %error,
                    "Supervision socket connection failed"
                );

                if attempt < MAX_SOCKET_CONN_RETRY_COUNT {
                    tokio::time::sleep(Duration::from_millis(SOCKET_CONN_RETRY_DELAY_MS)).await;
                }
            }
        }
    }

    false
}

/// Sends the registration handshake to the supervisor.
///
/// # Errors
/// Returns [`RdeError::Socket`] when the request cannot be written.
async fn register(client: &mut IpcClient, version: &str) -> RdeResult<()> {
    let request = ServiceRequest::Register(RegisterRequest {
        name: SERVICE_NAME.to_string(),
        pid: process::id(),
        version: version.to_string(),
        capabilities: CAPABILITIES
            .iter()
            .map(|item| (*item).to_string())
            .collect(),
    });

    client
        .send_service_requst(request)
        .await
        .map_err(|error| RdeError::Socket(error.to_string()))?;

    Ok(())
}

/// Sends a deregistration notice to the supervisor.
///
/// # Errors
/// Returns [`RdeError::Socket`] when the request cannot be written.
async fn deregister(client: &mut IpcClient) -> RdeResult<()> {
    let request = ServiceRequest::Deregister {
        name: SERVICE_NAME.to_string(),
        pid: process::id(),
    };

    client
        .send_service_requst(request)
        .await
        .map_err(|error| RdeError::Socket(error.to_string()))?;

    debug!(service = SERVICE_NAME, "Deregistration request sent");
    Ok(())
}
