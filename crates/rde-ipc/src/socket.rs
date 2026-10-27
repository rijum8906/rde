use std::path::{Path, PathBuf};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};

use async_trait::async_trait;
use rde_core::errors::RdeResult;

use crate::client::IpcClient;
use crate::error::{IpcError, IpcResult};
use crate::message::{Message, ServiceRequest};

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

    /// accept a new connection and wrap it in a [`UnixIpcClient`]
    pub async fn accept_client(&self) -> RdeResult<UnixIpcClient> {
        let stream = self.accept().await?;
        Ok(UnixIpcClient::from(stream))
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

/// Production [`IpcClient`] over a Unix-domain socket.
///
/// # SECURITY:
/// - Ensure the client validates that it is connecting to the correct socket path owned by the daemon.
///
/// # NOTE:
/// - Employs a length-prefixed protocol with a 4-byte Little-Endian prefix followed by JSON payload.
#[derive(Debug, Default)]
pub struct UnixIpcClient {
    is_connected: bool,
    stream: Option<UnixStream>,
    socket_path: Option<PathBuf>,
}

impl From<UnixStream> for UnixIpcClient {
    fn from(value: UnixStream) -> Self {
        Self {
            is_connected: true,
            stream: Some(value),
            // The peer chose the address; only a client that dialled knows the path.
            socket_path: None,
        }
    }
}

impl UnixIpcClient {
    /// Connects to `socket_path` and returns the ready client.
    ///
    /// # Parameters
    /// - `socket_path`: path of the socket owned by `rde-daemon`
    ///
    /// # Errors
    /// Returns [`IpcError::Connection`] when the socket cannot be reached.
    pub async fn connect_to(socket_path: impl AsRef<Path>) -> IpcResult<Self> {
        let mut client = Self::default();
        client.connect(socket_path.as_ref()).await?;
        Ok(client)
    }

    /// Closes the connection.
    ///
    /// Deprecated in favour of [`IpcClient::disconnect`], which is also part of
    /// the [`IpcClient`] contract.
    ///
    /// # Errors
    /// Returns [`IpcError::Io`] when the shutdown call fails.
    #[deprecated(note = "use IpcClient::disconnect instead")]
    pub async fn close(&mut self) -> IpcResult<()> {
        self.disconnect().await
    }

    /// Sends a service-to-daemon request.
    ///
    /// Deprecated in favour of [`IpcClient::send_service_request`], which fixes
    /// the misspelling of this method.
    ///
    /// # Errors
    /// Returns [`IpcError::NotConnected`] when there is no connection.
    #[deprecated(note = "use IpcClient::send_service_request instead")]
    pub async fn send_service_requst(&mut self, request: ServiceRequest) -> IpcResult<u64> {
        self.send_service_request(request).await
    }
}

#[async_trait]
impl IpcClient for UnixIpcClient {
    /// Connects to the daemon's socket.
    async fn connect(&mut self, socket_path: &Path) -> IpcResult<()> {
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

    fn is_connected(&self) -> bool {
        self.is_connected
    }

    fn socket_path(&self) -> Option<&Path> {
        self.socket_path.as_deref()
    }

    async fn disconnect(&mut self) -> IpcResult<()> {
        // Step 1: Take the stream so the client is left idle whichever way the
        // shutdown below ends.
        self.is_connected = false;
        self.socket_path = None;

        let Some(mut stream) = self.stream.take() else {
            // Step 2: Disconnecting an idle client is a no-op, not an error.
            return Ok(());
        };

        // Step 3: Report a failed shutdown, but never keep the stream alive.
        stream.shutdown().await.map_err(IpcError::Io)
    }

    /// Writes a raw message envelope.
    async fn send(&mut self, message: &Message) -> IpcResult<u64> {
        let Some(stream) = self.stream.as_mut() else {
            return Err(IpcError::NotConnected);
        };

        let data = serde_json::to_vec(message).map_err(|e| IpcError::InvalidArgs(e.to_string()))?;
        let len = data.len() as u32;

        // Send length first (4 bytes, Little-Endian as per spec)
        stream.write_all(&len.to_le_bytes()).await?;

        // Send the payload
        stream.write_all(&data).await?;
        stream.flush().await?;

        Ok(message.message_id)
    }

    /// Receives a raw message envelope.
    async fn recv(&mut self) -> IpcResult<Message> {
        let Some(stream) = self.stream.as_mut() else {
            return Err(IpcError::NotConnected);
        };

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

        serde_json::from_slice(&buf).map_err(|e| IpcError::InvalidArgs(e.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::message::{
        AckResponse, DaemonRequest, DaemonResponse, GetStatusRequest, MessagePayload,
        RegisterRequest, ServiceRequest, ServiceResponse, types::ServiceStatus,
    };
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
        let mut client = UnixIpcClient::default();
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
    async fn connect_to_round_trips_a_frame_and_disconnects_idempotently() -> IpcResult<()> {
        let temp_dir = tempdir()?;
        let socket_path = temp_dir.path().join("rde-client-test.sock");

        let server = IpcServer::new_with_path(socket_path.clone())?;
        let server_handle = tokio::spawn(async move {
            let mut peer = server.accept_client().await.unwrap();

            // The peer answers the frame the client writes below.
            let request = peer.recv().await.unwrap();
            assert!(matches!(
                request.payload,
                MessagePayload::DaemonRequest(DaemonRequest::HealthCheck)
            ));
            peer.send_daemon_response(DaemonResponse::RegisterAck(AckResponse {
                success: true,
                reason: None,
            }))
            .await
            .unwrap();

            server.shutdown().unwrap();
        });

        // Step 1: The constructor returns a client that already knows its path.
        let mut client = UnixIpcClient::connect_to(&socket_path).await?;
        assert!(client.is_connected());
        assert_eq!(client.socket_path(), Some(socket_path.as_path()));

        // Step 2: A frame written by the client is answered on the same socket.
        client
            .send_daemon_request(DaemonRequest::HealthCheck)
            .await?;
        let response = client.recv().await?;
        assert!(matches!(
            response.payload,
            MessagePayload::DaemonResponse(DaemonResponse::RegisterAck(_))
        ));

        // Step 3: Disconnecting releases the connection, and doing it twice is a
        // no-op rather than an error.
        client.disconnect().await?;
        assert!(!client.is_connected());
        assert_eq!(client.socket_path(), None);
        client
            .disconnect()
            .await
            .expect("a second disconnect must be a no-op");
        assert!(matches!(client.recv().await, Err(IpcError::NotConnected)));

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
        let mut client = UnixIpcClient::default();
        client.connect(&socket_path).await.unwrap();

        // 1. Send registration request
        let request = ServiceRequest::Register(RegisterRequest {
            name: "test-service".to_string(),
            pid: 1234,
            version: "0.1.0".to_string(),
            capabilities: vec![],
        });
        client.send_service_request(request).await?;

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
