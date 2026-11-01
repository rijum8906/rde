//! # IPC Socket Primitives

use std::path::{Path, PathBuf};
use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tokio_util::sync::CancellationToken;

use crate::error::{IpcError, IpcResult};
use crate::message::{
    DaemonRequest, DaemonResponse, Message, MessagePayload, RegisterRequest, ServiceRequest,
    ServiceResponse,
};

// =============================
// ======= Socket Server =======
// =============================

pub struct IpcServer {
    listener: UnixListener,
    socket_path: PathBuf,
    cancellation_token: CancellationToken,
}

impl IpcServer {
    pub fn new() -> IpcResult<Self> {
        let path =
            rde_core::utils::ipc::get_socket_path().map_err(|e| IpcError::Socket(e.to_string()))?;
        Self::bind(path)
    }

    pub fn new_with_path(socket_path: PathBuf) -> IpcResult<Self> {
        Self::bind(socket_path)
    }

    fn bind(socket_path: PathBuf) -> IpcResult<Self> {
        if socket_path.exists() {
            let _ = std::fs::remove_file(&socket_path);
        }

        let listener = UnixListener::bind(&socket_path)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&socket_path, std::fs::Permissions::from_mode(0o600))?;
        }

        Ok(Self {
            listener,
            socket_path,
            cancellation_token: CancellationToken::new(),
        })
    }

    /// Accepts a new connection and returns the client.
    pub async fn accept_client(&self) -> IpcResult<UnixIpcClient> {
        let (stream, _) = self.listener.accept().await?;
        Ok(UnixIpcClient::from(stream))
    }

    pub fn socket_path(&self) -> &Path {
        &self.socket_path
    }

    pub fn shutdown(&self) -> IpcResult<()> {
        // 1. Cancel all spawned tasks
        self.cancellation_token.cancel();

        // 2. Remove the socket file
        if self.socket_path.exists() {
            std::fs::remove_file(&self.socket_path)?;
        }
        Ok(())
    }

    /// Returns a token that triggers when the server shuts down.
    pub fn cancellation_token(&self) -> CancellationToken {
        self.cancellation_token.clone()
    }
}

// ============================================
// SOCKET CLIENT (Service Side)
// ============================================

#[derive(Default)]
pub struct UnixIpcClient {
    is_connected: bool,
    stream: Option<UnixStream>,
    socket_path: Option<PathBuf>,
}

impl std::fmt::Debug for UnixIpcClient {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("UnixIpcClient")
            .field("is_connected", &self.is_connected)
            .field("socket_path", &self.socket_path)
            .finish()
    }
}

impl From<UnixStream> for UnixIpcClient {
    fn from(value: UnixStream) -> Self {
        Self {
            is_connected: true,
            stream: Some(value),
            socket_path: None,
        }
    }
}

impl UnixIpcClient {
    pub async fn connect_to(socket_path: impl AsRef<Path>) -> IpcResult<Self> {
        let mut client = Self::default();
        client.connect(socket_path.as_ref()).await?;
        Ok(client)
    }

    pub async fn connect(&mut self, socket_path: &Path) -> IpcResult<()> {
        let stream = UnixStream::connect(socket_path)
            .await
            .map_err(|e| IpcError::Connection {
                message: "Failed to connect".to_string(),
                reason: e.to_string(),
            })?;

        self.stream = Some(stream);
        self.is_connected = true;
        self.socket_path = Some(socket_path.to_path_buf());
        Ok(())
    }

    pub fn is_connected(&self) -> bool {
        self.is_connected
    }

    pub fn socket_path(&self) -> Option<&Path> {
        self.socket_path.as_deref()
    }

    pub async fn disconnect(&mut self) -> IpcResult<()> {
        self.is_connected = false;
        self.socket_path = None;
        let Some(mut stream) = self.stream.take() else {
            return Ok(());
        };
        stream.shutdown().await.map_err(IpcError::Io)
    }

    pub async fn send(&mut self, message: &Message) -> IpcResult<u64> {
        let Some(stream) = self.stream.as_mut() else {
            return Err(IpcError::NotConnected);
        };
        let data = message.encode()?;
        stream.write_all(&data).await?;
        stream.flush().await?;
        Ok(message.message_id)
    }

    pub async fn recv(&mut self) -> IpcResult<Message> {
        let Some(stream) = self.stream.as_mut() else {
            return Err(IpcError::NotConnected);
        };

        let mut len_buf = [0u8; 4];
        stream.read_exact(&mut len_buf).await?;
        let len = u32::from_be_bytes(len_buf) as usize;

        if len > 64 * 1024 * 1024 {
            return Err(IpcError::InvalidArgs("Payload too large".to_string()));
        }

        let mut buf = vec![0u8; len];
        stream.read_exact(&mut buf).await?;
        Ok(Message::decode(&buf)?)
    }

    pub async fn recv_timeout(&mut self, timeout: Duration) -> IpcResult<Message> {
        tokio::time::timeout(timeout, self.recv())
            .await
            .map_err(|_| IpcError::Timeout(timeout))?
    }

    pub async fn connect_with_retry(
        &mut self,
        socket_path: &Path,
        attempts: u32,
        delay: Duration,
    ) -> IpcResult<()> {
        let attempts = attempts.max(1);
        let mut last_error = None;

        for attempt in 1..=attempts {
            match self.connect(socket_path).await {
                Ok(()) => return Ok(()),
                Err(error) => {
                    last_error = Some(error);
                    if attempt < attempts {
                        tokio::time::sleep(delay).await;
                    }
                }
            }
        }

        Err(last_error.unwrap_or(IpcError::ConnectionFailed))
    }

    // =============================
    // === Typed Send Helpers ======
    // =============================

    pub async fn send_daemon_request(&mut self, request: DaemonRequest) -> IpcResult<u64> {
        self.send(&Message::new(MessagePayload::DaemonRequest(request)))
            .await
    }

    pub async fn send_daemon_response(&mut self, response: DaemonResponse) -> IpcResult<u64> {
        self.send(&Message::new(MessagePayload::DaemonResponse(response)))
            .await
    }

    pub async fn send_service_request(&mut self, request: ServiceRequest) -> IpcResult<u64> {
        self.send(&Message::new(MessagePayload::ServiceRequest(request)))
            .await
    }

    pub async fn send_service_response(&mut self, response: ServiceResponse) -> IpcResult<u64> {
        self.send(&Message::new(MessagePayload::ServiceResponse(response)))
            .await
    }

    pub async fn register(
        &mut self,
        name: &str,
        version: &str,
        capabilities: &[&str],
    ) -> IpcResult<u64> {
        let req = ServiceRequest::Register(RegisterRequest {
            name: name.to_string(),
            pid: std::process::id(),
            version: version.to_string(),
            capabilities: capabilities.iter().map(|s| s.to_string()).collect(),
        });
        self.send_service_request(req).await
    }

    pub async fn deregister(&mut self, name: &str, pid: u32) -> IpcResult<u64> {
        let req = ServiceRequest::Deregister {
            name: name.to_string(),
            pid,
        };
        self.send_service_request(req).await
    }
}
