use std::{path::Path, time::Duration};

use async_trait::async_trait;
use tracing::warn;

use crate::{
    error::{IpcError, IpcResult},
    message::{
        DaemonRequest, DaemonResponse, Message, MessagePayload, RegisterRequest, ServiceRequest,
        ServiceResponse,
    },
};

#[async_trait]
pub trait IpcClient: Send + Sync {
    async fn connect(&mut self, socket_path: &Path) -> IpcResult<()>;
    fn is_connected(&self) -> bool;
    fn socket_path(&self) -> Option<&Path>;
    async fn disconnect(&mut self) -> IpcResult<()>;
    async fn send(&mut self, message: &Message) -> IpcResult<u64>;
    async fn recv(&mut self) -> IpcResult<Message>;

    // === Provided Helpers ===

    async fn connect_with_retry(
        &mut self,
        socket_path: &Path,
        attempts: u32,
        delay: Duration,
    ) -> IpcResult<()> {
        let attempts = attempts.max(1);
        let mut last_error = None;

        for attempt in 1..=attempts {
            match self.connect(socket_path).await {
                Ok(()) => {
                    tracing::info!(
                        attempt,
                        max_attempts = attempts,
                        path = %socket_path.display(),
                        "Connected to the supervision socket"
                    );
                    return Ok(());
                }
                Err(error) => {
                    warn!(
                        attempt,
                        max_attempts = attempts,
                        path = %socket_path.display(),
                        %error,
                        "Supervision socket connection failed"
                    );
                    last_error = Some(error);
                    if attempt < attempts {
                        tokio::time::sleep(delay).await;
                    }
                }
            }
        }

        Err(last_error.unwrap_or(IpcError::Connection {
            message: "No connection attempt was made".to_string(),
            reason: "attempts must be at least one".to_string(),
        }))
    }

    async fn recv_timeout(&mut self, timeout: Duration) -> IpcResult<Message> {
        tokio::time::timeout(timeout, self.recv())
            .await
            .map_err(|_| IpcError::Timeout(timeout))?
    }

    async fn send_service_request(&mut self, request: ServiceRequest) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::ServiceRequest(request));
        self.send(&message).await
    }

    async fn send_service_response(&mut self, response: ServiceResponse) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::ServiceResponse(response));
        self.send(&message).await
    }

    async fn send_daemon_request(&mut self, request: DaemonRequest) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::DaemonRequest(request));
        self.send(&message).await
    }

    async fn send_daemon_response(&mut self, response: DaemonResponse) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::DaemonResponse(response));
        self.send(&message).await
    }

    async fn register(
        &mut self,
        name: &str,
        version: &str,
        capabilities: &[&str],
    ) -> IpcResult<u64> {
        let request = ServiceRequest::Register(RegisterRequest {
            name: name.to_string(),
            pid: std::process::id(),
            version: version.to_string(),
            capabilities: capabilities
                .iter()
                .map(|item| (*item).to_string())
                .collect(),
        });

        self.send_service_request(request).await
    }

    async fn deregister(&mut self, name: &str, pid: u32) -> IpcResult<u64> {
        let request = ServiceRequest::Deregister {
            name: name.to_string(),
            pid,
        };
        self.send_service_request(request).await
    }
}
