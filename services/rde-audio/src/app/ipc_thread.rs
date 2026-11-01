use rde_core::utils::{ipc::get_socket_path, ipc_task_handler::IpcTaskHandler};
use rde_ipc::{
    error::{IpcError, IpcResult},
    socket::UnixIpcClient,
};
use tokio_util::sync::CancellationToken;

use crate::app::App;

impl App {
    pub fn handle_ipc_thread(&mut self) {
        let mut ipc_thread = IpcTaskHandler::new();
        let cancellation_token = ipc_thread.cancellation_token.clone();

        // Store the JoinHandle so we can await it during shutdown
        let handle = tokio::spawn(async move {
            Self::run_ipc_loop(cancellation_token).await;
        });

        // Save the handle to the app so we can join it later
        ipc_thread.handle = Some(handle);
        self.ipc_thread = Some(ipc_thread);
    }

    async fn run_ipc_loop(cancellation_token: CancellationToken) {
        let socket_path = match get_socket_path() {
            Ok(path) => path,
            Err(e) => {
                tracing::error!("Failed to get socket path: {}", e);
                return;
            }
        };

        let mut ipc_client =
            match Self::connect_with_retry(&socket_path, cancellation_token.clone()).await {
                Ok(client) => client,
                Err(e) => {
                    tracing::error!("Failed to connect to IPC after retries: {}", e);
                    return;
                }
            };

        tracing::info!("Connected to IPC daemon at {}", socket_path.display());

        // Main receive loop
        loop {
            tokio::select! {
                // 1. Check for shutdown signal
                _ = cancellation_token.cancelled() => {
                    tracing::info!("IPC loop received cancellation signal. Shutting down.");
                    break;
                }

                // 2. Await the next message from the daemon
                msg_result = ipc_client.recv() => {
                    match msg_result {
                        Ok(msg) => {
                            tracing::debug!("Received IPC message: {:?}", msg);
                            // Route your message here!
                            // e.g., match msg { IpcResponse::Volume(v) => ... }
                        }
                        Err(e) => {
                            tracing::error!("IPC connection lost: {}", e);
                            break; // Exit the loop if the socket dies
                        }
                    }
                }
            }
        }
    }

    /// Attempts to connect to the daemon, retrying every 500ms up to 10 times.
    /// Listens for the cancellation token so it doesn't hang if the app closes during startup.
    async fn connect_with_retry(
        socket_path: &std::path::Path,
        cancellation_token: CancellationToken,
    ) -> IpcResult<UnixIpcClient> {
        let max_attempts = 10;
        let mut last_err = None;

        for attempt in 1..=max_attempts {
            tokio::select! {
                // Abort connection attempt if the app is shutting down
                _ = cancellation_token.cancelled() => {
                    return Err(IpcError::ConnectionAborted);
                }

                result = UnixIpcClient::connect_to(socket_path) => {
                    match result {
                        Ok(client) => return Ok(client),
                        Err(e) => {
                            tracing::warn!("IPC connect failed (attempt {}/{}): {}", attempt, max_attempts, e);
                            last_err = Some(e);
                        }
                    }
                }
            }

            // Wait 500ms before retrying
            tokio::select! {
                _ = cancellation_token.cancelled() => return Err(IpcError::ConnectionAborted),
                _ = tokio::time::sleep(std::time::Duration::from_millis(500)) => {}
            }
        }

        Err(last_err.unwrap_or(IpcError::ConnectionFailed))
    }
}
