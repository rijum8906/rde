use std::path::{Path, PathBuf};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};

use rde_core::errors::RdeResult;

use crate::error::{IpcError, IpcResult};
use crate::message::{
    DaemonRequest, DaemonResponse, Message, MessagePayload, ServiceRequest, ServiceResponse,
};

// =============================
// ======= Socket Server =========
// =============================

/// IPC Server: A socket server that listens on a Unix socket
/// and helps in communication between services.
///
/// # SECURITY:
/// - Socket file permissions are set to `0o600` (owner read/write only) to restrict access.
/// - Parent directory permissions must be `0o700` (owner read/write/execute only).
///
/// # NOTE:
/// - Communicates asynchronously using Tokio's Unix domain sockets.
///
/// # TODO:
/// - Implement connection rate-limiting to prevent potential Denial of Service (DoS) attacks.
pub struct IpcServer {
    pub listener: UnixListener,
    socket_path: PathBuf,
}

impl From<PathBuf> for IpcServer {
    fn from(value: PathBuf) -> Self {
        let listener = UnixListener::bind(&value).unwrap();

        // Set permissions (read/write for owner only - 0o600 as per design spec)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&value, std::fs::Permissions::from_mode(0o600)).unwrap();
        }

        IpcServer {
            listener,
            socket_path: value,
        }
    }
}

impl From<&Path> for IpcServer {
    fn from(value: &Path) -> Self {
        Self::from(PathBuf::from(value))
    }
}

impl IpcServer {
    pub fn new() -> RdeResult<Self> {
        // Use the centralized socket path utility from rde-core
        let socket_path = rde_core::utils::ipc::get_socket_path()?;

        // Create the listener
        let listener = UnixListener::bind(&socket_path)?;

        // Set permissions (read/write for owner only - 0o600 as per design spec)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&socket_path, std::fs::Permissions::from_mode(0o600))?;
        }

        Ok(IpcServer {
            listener,
            socket_path,
        })
    }

    /// Create a new IPC Server listening on a custom socket path
    pub fn new_with_path(socket_path: PathBuf) -> IpcResult<Self> {
        // Create the listener
        let listener = UnixListener::bind(&socket_path)?;

        // Set permissions (read/write for owner only - 0o600 as per design spec)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&socket_path, std::fs::Permissions::from_mode(0o600))?;
        }

        Ok(IpcServer {
            listener,
            socket_path,
        })
    }

    /// accept a new connection
    pub async fn accept(&self) -> RdeResult<UnixStream> {
        let (stream, addr) = self.listener.accept().await?;
        tracing::debug!("🔗 New connection from: {:?}", addr);
        Ok(stream)
    }

    /// accept a new connection and wrap it in an IpcClient
    pub async fn accept_client(&self) -> RdeResult<IpcClient> {
        let stream = self.accept().await?;
        Ok(IpcClient::from(stream))
    }

    /// get the socket path
    pub fn socket_path(&self) -> &PathBuf {
        &self.socket_path
    }

    /// Close the socket and cleanup
    pub fn shutdown(&self) -> RdeResult<()> {
        if self.socket_path.exists() {
            std::fs::remove_file(&self.socket_path)?;
            tracing::info!("🧹 Socket cleaned up: {}", self.socket_path.display());
        }
        Ok(())
    }
}

// ============================================
// SOCKET CLIENT (Service Side)
// ============================================

/// IPC Client: Connects to the daemon's supervision socket.
///
/// # SECURITY:
/// - Ensure the client validates that it is connecting to the correct socket path owned by the daemon.
///
/// # NOTE:
/// - Employs a length-prefixed protocol with a 4-byte Little-Endian prefix followed by JSON payload.
#[derive(Debug, Default)]
pub struct IpcClient {
    is_connected: bool,
    stream: Option<UnixStream>,
}

impl From<UnixStream> for IpcClient {
    fn from(value: UnixStream) -> Self {
        Self {
            is_connected: true,
            stream: Some(value),
        }
    }
}

impl IpcClient {
    pub fn is_connected(&self) -> bool {
        self.is_connected
    }

    /// Connect to the daemon's socket
    pub async fn connect(&mut self, socket_path: &PathBuf) -> IpcResult<()> {
        let stream = UnixStream::connect(socket_path)
            .await
            .map_err(|e| IpcError::Connection {
                message: "Failed to connect".to_string(),
                reason: e.to_string(),
            })?;

        self.stream = Some(stream);
        self.is_connected = true;

        Ok(())
    }

    /// Close the connection
    pub async fn close(&mut self) -> IpcResult<()> {
        if let Some(mut stream) = self.stream.take() {
            stream.shutdown().await?;
            self.is_connected = false;
        }

        Err(IpcError::NotConnected)
    }

    /// Send a raw message envelope
    pub async fn send(&mut self, msg: &Message) -> IpcResult<()> {
        if let Some(stream) = self.stream.as_mut() {
            let data = serde_json::to_vec(msg).map_err(|e| IpcError::InvalidArgs(e.to_string()))?;
            let len = data.len() as u32;

            // Send length first (4 bytes, Little-Endian as per spec)
            stream.write_all(&len.to_le_bytes()).await?;

            // Send the payload
            stream.write_all(&data).await?;
            stream.flush().await?;

            return Ok(());
        }

        Err(IpcError::NotConnected)
    }

    /// Send a request payload (automatically wrapped in a Message envelope)
    pub async fn send_daemon_request(&mut self, req: DaemonRequest) -> IpcResult<u64> {
        let msg = Message::new(MessagePayload::DaemonRequest(req));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a request payload (automatically wrapped in a Message envelope)
    pub async fn send_service_requst(&mut self, req: ServiceRequest) -> IpcResult<u64> {
        let msg = Message::new(MessagePayload::ServiceRequest(req));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a response payload (automatically wrapped in a Message envelope)
    pub async fn send_daemon_response(&mut self, resp: DaemonResponse) -> IpcResult<u64> {
        let msg = Message::new(MessagePayload::DaemonResponse(resp));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a response payload (automatically wrapped in a Message envelope)
    pub async fn send_service_response(&mut self, resp: ServiceResponse) -> IpcResult<u64> {
        let msg = Message::new(MessagePayload::ServiceResponse(resp));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Receive a raw message envelope
    pub async fn recv(&mut self) -> IpcResult<Message> {
        if let Some(stream) = self.stream.as_mut() {
            // Read message length (4 bytes)
            let mut len_buf = [0u8; 4];
            stream
                .read_exact(&mut len_buf)
                .await
                .map_err(IpcError::Io)?;
            let len = u32::from_le_bytes(len_buf) as usize;

            // Read the message
            let mut buf = vec![0u8; len];
            stream.read_exact(&mut buf).await?;

            let msg: Message =
                serde_json::from_slice(&buf).map_err(|e| IpcError::InvalidArgs(e.to_string()))?;

            return Ok(msg);
        }

        Err(IpcError::NotConnected)
    }

    /// Receive a message with a timeout
    pub async fn recv_timeout(&mut self, duration: std::time::Duration) -> IpcResult<Message> {
        tokio::time::timeout(duration, self.recv())
            .await
            .map_err(|_| IpcError::Socket("Timeout receiving message".to_string()))?
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::message::{AckResponse, GetStatusRequest, RegisterRequest, types::ServiceStatus};
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_daemon_request_and_service_response() -> IpcResult<()> {
        let temp_dir = tempdir()?;
        let socket_path = temp_dir.path().join("rde-daemon-test.sock");

        // Initialize IPC Server with custom socket path
        let server = IpcServer::from(socket_path.clone());

        // Spawn server handling task
        let server_handle = tokio::spawn(async move {
            let mut client = server.accept_client().await.unwrap();

            // 1. Server sends a DaemonRequest::HealthCheck liveness check
            client
                .send_daemon_request(DaemonRequest::HealthCheck)
                .await
                .unwrap();

            // Server receives ServiceResponse::Alive liveness acknowledgment
            let msg = client.recv().await.unwrap();
            assert!(matches!(
                msg.payload,
                MessagePayload::ServiceResponse(ServiceResponse::Alive)
            ));

            // 2. Server sends a DaemonRequest::GetStatus status query
            client
                .send_daemon_request(DaemonRequest::GetStatus(GetStatusRequest {
                    name: "test-service".to_string(),
                }))
                .await
                .unwrap();

            // Server receives ServiceResponse::Status liveness acknowledgment
            let msg = client.recv().await.unwrap();
            if let MessagePayload::ServiceResponse(ServiceResponse::Status(status)) = msg.payload {
                assert_eq!(status, ServiceStatus::Running);
            } else {
                panic!("Expected ServiceResponse::Status");
            }

            server.shutdown().unwrap();
        });

        // Connect client
        let mut client = IpcClient::default();
        client.connect(&socket_path).await.unwrap();

        // 1. Receive HealthCheck request
        let msg = client.recv().await?;
        assert!(matches!(
            msg.payload,
            MessagePayload::DaemonRequest(DaemonRequest::HealthCheck)
        ));

        // Reply with ServiceResponse::Alive
        client.send_service_response(ServiceResponse::Alive).await?;

        // 2. Receive GetStatus request
        let msg = client.recv().await?;
        if let MessagePayload::DaemonRequest(DaemonRequest::GetStatus(req)) = msg.payload {
            assert_eq!(req.name, "test-service");
        } else {
            panic!("Expected DaemonRequest::GetStatus");
        }

        // Reply with ServiceResponse::Status
        client
            .send_service_response(ServiceResponse::Status(ServiceStatus::Running))
            .await?;

        // Wait for server task to finish
        server_handle.await.unwrap();

        Ok(())
    }

    #[tokio::test]
    async fn test_service_request_and_daemon_response() -> IpcResult<()> {
        let temp_dir = tempdir()?;
        let socket_path = temp_dir.path().join("rde-service-test.sock");

        // Initialize IPC Server with custom socket path
        let server = IpcServer::new_with_path(socket_path.clone())?;

        // Spawn server handling task
        let server_handle = tokio::spawn(async move {
            let mut client = server.accept_client().await.unwrap();

            // 1. Receive registration request from client
            let msg = client.recv().await.unwrap();
            if let MessagePayload::ServiceRequest(ServiceRequest::Register(reg)) = msg.payload {
                assert_eq!(reg.name, "test-service");
                assert_eq!(reg.pid, 1234);
                assert_eq!(reg.version, "0.1.0");
            } else {
                panic!("Expected ServiceRequest::Register");
            }

            // Send back RegisterAck response
            let response = DaemonResponse::RegisterAck(AckResponse {
                success: true,
                reason: Some("Registered".to_string()),
            });
            client.send_daemon_response(response).await.unwrap();

            server.shutdown().unwrap();
        });

        // Connect client
        let mut client = IpcClient::default();
        client.connect(&socket_path).await.unwrap();

        // 1. Send registration request
        let request = ServiceRequest::Register(RegisterRequest {
            name: "test-service".to_string(),
            pid: 1234,
            version: "0.1.0".to_string(),
            capabilities: vec![],
        });
        client.send_service_requst(request).await?;

        // Receive response
        let response = client.recv().await?;
        if let MessagePayload::DaemonResponse(DaemonResponse::RegisterAck(ack)) = response.payload {
            assert!(ack.success);
            assert_eq!(ack.reason.unwrap(), "Registered");
        } else {
            panic!("Expected DaemonResponse::RegisterAck");
        }

        // Wait for server task to finish
        server_handle.await.unwrap();

        Ok(())
    }
}
