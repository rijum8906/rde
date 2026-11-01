//! # Daemon Supervision
//!
//! Connects to the `rde-daemon` Unix socket, registers the brightness service,
//! answers health, status, and shutdown requests, and deregisters on exit.

use std::{
    path::Path,
    process,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use anyhow::anyhow;
use rde_core::utils::ipc::get_socket_path;
use rde_ipc::{
    IpcCommand, IpcThread,
    error::IpcError,
    message::{
        DaemonRequest, DaemonResponse, Message, MessagePayload, RegisterRequest, ServiceRequest,
        ServiceResponse, ServiceStatus,
    },
    socket::UnixIpcClient,
};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{debug, info, warn};

use crate::{
    CAPABILITIES, MAX_SOCKET_CONN_RETRY_COUNT, SERVICE_NAME, SERVICE_VERSION, SHUTDOWN_TIMEOUT,
    SOCKET_CONN_RETRY_DELAY_MS,
};

/// Lock-free view of the runtime state used to answer supervisor requests.
#[derive(Clone)]
struct SupervisionContext {
    /// Mirrors the supervision task's running flag.
    running: Arc<AtomicBool>,

    /// Cancels the application event loop on a supervisor shutdown request.
    shutdown: CancellationToken,
}

impl SupervisionContext {
    /// Returns the status reported to the supervisor.
    fn status(&self) -> ServiceStatus {
        if self.running.load(Ordering::Relaxed) {
            ServiceStatus::Running
        } else {
            ServiceStatus::Stopped
        }
    }
}

/// Spawns the supervision task and returns its handle.
///
/// Supervision is optional: when the daemon socket cannot be reached the task
/// stops after the retry budget while the D-Bus service keeps running.
///
/// # Parameters
/// - `shutdown`: application token cancelled when the supervisor asks to stop
pub fn spawn(shutdown: CancellationToken) -> IpcThread {
    let (tx, mut rx) = mpsc::channel::<IpcCommand>(4);
    let cancellation_token = CancellationToken::new();
    let task_token = cancellation_token.clone();
    let running = Arc::new(AtomicBool::new(true));
    let context = SupervisionContext {
        running: Arc::clone(&running),
        shutdown,
    };

    debug!("Spawning the daemon supervision task");

    let handle = tokio::spawn(async move {
        // Step 1: Resolve the socket path; supervision is optional.
        let socket_path = match get_socket_path() {
            Ok(path) => path,
            Err(error) => {
                warn!(%error, "Unable to resolve the daemon socket path");
                running.store(false, Ordering::Relaxed);
                return;
            }
        };

        // Step 2: Connect using the shared retry policy.
        let mut client = UnixIpcClient::default();
        if !connect(&mut client, &socket_path).await {
            warn!(
                attempts = MAX_SOCKET_CONN_RETRY_COUNT,
                "Giving up on daemon supervision, service continues unsupervised"
            );
            running.store(false, Ordering::Relaxed);
            return;
        }

        // Step 3: Announce the service to the supervisor.
        if let Err(error) = register(&mut client).await {
            warn!(%error, "Registration failed, service continues unsupervised");
        }

        // Step 4: Serve messages until cancelled, stopped, or disconnected.
        let reason = loop {
            tokio::select! {
                _ = task_token.cancelled() => break "cancellation requested",
                command = rx.recv() => match command {
                    Some(IpcCommand::Shutdown) => break "shutdown command received",
                    None => break "command channel closed",
                },
                received = client.recv() => match received {
                    Ok(message) => {
                        if let Err(error) = handle_message(message, &mut client, &context).await {
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
        running.store(false, Ordering::Relaxed);

        // Step 5: Best-effort cleanup so the supervisor drops the entry now.
        if let Err(error) = deregister(&mut client).await {
            debug!(%error, "Could not tell the supervisor about the disconnect");
        }
    });

    IpcThread {
        tx,
        handle,
        cancellation_token,
    }
}

/// Stops the supervision task and waits for it, bounded by [`SHUTDOWN_TIMEOUT`].
///
/// # Parameters
/// - `ipc`: handle returned by [`spawn`]
pub async fn stop(ipc: IpcThread) {
    // Step 1: Ask the task to stop through both of its exit paths.
    ipc.cancellation_token.cancel();
    if let Err(error) = ipc.tx.send(IpcCommand::Shutdown).await {
        debug!(%error, "Supervision task already stopped accepting commands");
    }

    // Step 2: Bounded wait so a stuck socket cannot block exit.
    match tokio::time::timeout(SHUTDOWN_TIMEOUT, ipc.handle).await {
        Ok(Ok(())) => debug!("Supervision task stopped"),
        Ok(Err(error)) => warn!(%error, "Supervision task terminated with an error"),
        Err(_) => warn!("Timed out waiting for the supervision task to stop"),
    }
}

/// Routes one supervisor message to its handler.
async fn handle_message(
    message: Message,
    client: &mut UnixIpcClient,
    context: &SupervisionContext,
) -> anyhow::Result<()> {
    match message.payload {
        MessagePayload::DaemonRequest(request) => {
            debug!("Routing supervisor request to its handler");
            handle_request(request, client, context).await
        }
        MessagePayload::DaemonResponse(response) => {
            handle_response(response);
            Ok(())
        }
        payload => {
            debug!(?payload, "Ignoring unexpected message from the supervisor");
            Ok(())
        }
    }
}

/// Answers a request pushed by the supervisor.
async fn handle_request(
    request: DaemonRequest,
    client: &mut UnixIpcClient,
    context: &SupervisionContext,
) -> anyhow::Result<()> {
    match request {
        DaemonRequest::HealthCheck => {
            debug!("Received health check probe from the supervisor");
            client
                .send_service_response(ServiceResponse::Alive)
                .await
                .map_err(socket_error)?;
        }

        DaemonRequest::GetStatus(query) => {
            let status = context.status();
            debug!(service = %query.name, ?status, "Reporting service status");
            client
                .send_service_response(ServiceResponse::Status(status))
                .await
                .map_err(socket_error)?;
        }

        DaemonRequest::Shutdown {
            service_name,
            reason,
        } => {
            info!(
                service = %service_name,
                reason = reason.as_deref().unwrap_or("unspecified"),
                "Shutdown requested by the supervisor"
            );

            // Only signal the request here: `stop` waits for this very task.
            context.shutdown.cancel();
        }
    }

    Ok(())
}

/// Logs a registration or administrative acknowledgement.
fn handle_response(response: DaemonResponse) {
    match response {
        DaemonResponse::RegisterAck(ack) => {
            if ack.success {
                info!(
                    service = SERVICE_NAME,
                    pid = process::id(),
                    "Supervisor acknowledged the registration"
                );
            } else {
                warn!(
                    service = SERVICE_NAME,
                    reason = ack.reason.as_deref().unwrap_or("unspecified"),
                    "Supervisor rejected the registration"
                );
            }
        }
        DaemonResponse::Success => {
            debug!(service = SERVICE_NAME, "Supervisor acknowledged a request");
        }
    }
}

/// Connects to the supervision socket, retrying with a fixed delay.
///
/// # Returns
/// `true` when a connection was established, `false` after the final attempt.
async fn connect(client: &mut UnixIpcClient, socket_path: &Path) -> bool {
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
async fn register(client: &mut UnixIpcClient) -> anyhow::Result<()> {
    let request = ServiceRequest::Register(RegisterRequest {
        name: SERVICE_NAME.to_string(),
        pid: process::id(),
        version: SERVICE_VERSION.to_string(),
        capabilities: CAPABILITIES
            .iter()
            .map(|item| (*item).to_string())
            .collect(),
    });

    client
        .send_service_request(request)
        .await
        .map_err(socket_error)?;

    Ok(())
}

/// Sends a deregistration notice to the supervisor.
async fn deregister(client: &mut UnixIpcClient) -> anyhow::Result<()> {
    let request = ServiceRequest::Deregister {
        name: SERVICE_NAME.to_string(),
        pid: process::id(),
    };

    client
        .send_service_request(request)
        .await
        .map_err(socket_error)?;

    debug!(service = SERVICE_NAME, "Deregistration request sent");
    Ok(())
}

/// Converts an IPC failure into a contextual error.
fn socket_error(error: IpcError) -> anyhow::Error {
    warn!(%error, "Failed to write to the supervision socket");
    anyhow!("supervision socket write failed: {error}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_follows_the_running_flag() {
        let context = SupervisionContext {
            running: Arc::new(AtomicBool::new(false)),
            shutdown: CancellationToken::new(),
        };

        assert_eq!(context.status(), ServiceStatus::Stopped);

        context.running.store(true, Ordering::Relaxed);
        assert_eq!(context.status(), ServiceStatus::Running);
    }
}
