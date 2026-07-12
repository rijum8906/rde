use std::path::PathBuf;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};

use rde_core::{
    errors::{RdeError, RdeResult, ipc::IpcError},
    logger::Logger,
};

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
    pub logger: Logger,
    socket_path: PathBuf,
}

impl IpcServer {
    pub fn new(logger: Logger) -> RdeResult<Self> {
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

        // log the socket path
        tracing::info!("🔌 IPC server listening on: {}", socket_path.display());

        Ok(IpcServer {
            listener,
            logger,
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
        Ok(IpcClient::new(stream))
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
pub struct IpcClient {
    stream: UnixStream,
}

impl IpcClient {
    /// Create a new IpcClient from an existing UnixStream
    pub fn new(stream: UnixStream) -> Self {
        Self { stream }
    }

    /// Connect to the daemon's socket
    pub async fn connect(socket_path: &PathBuf) -> RdeResult<Self> {
        tracing::debug!("🔌 Connecting to: {}", socket_path.display());

        let stream = UnixStream::connect(socket_path).await.map_err(|e| {
            tracing::error!("❌ Failed to connect to IPC socket: {}", e);
            RdeError::Socket(format!("Failed to connect: {}", e))
        })?;

        tracing::debug!("✅ Connected to IPC socket");

        Ok(Self { stream })
    }

    /// Send a raw message envelope
    pub async fn send(&mut self, msg: &Message) -> RdeResult<()> {
        let data = serde_json::to_vec(msg)
            .map_err(|e| RdeError::Ipc(IpcError::InvalidArgs(e.to_string())))?;
        let len = data.len() as u32;

        // Send length first (4 bytes, Little-Endian as per spec)
        self.stream.write_all(&len.to_le_bytes()).await?;

        // Send the payload
        self.stream.write_all(&data).await?;
        self.stream.flush().await?;

        tracing::trace!("📤 Sent: {:?}", msg);
        Ok(())
    }

    /// Send a request payload (automatically wrapped in a Message envelope)
    pub async fn send_daemon_request(&mut self, req: DaemonRequest) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::DaemonRequest(req));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a request payload (automatically wrapped in a Message envelope)
    pub async fn send_service_requst(&mut self, req: ServiceRequest) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::ServiceRequest(req));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a response payload (automatically wrapped in a Message envelope)
    pub async fn send_daemon_response(&mut self, resp: DaemonResponse) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::DaemonResponse(resp));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a response payload (automatically wrapped in a Message envelope)
    pub async fn send_service_response(&mut self, resp: ServiceResponse) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::ServiceResponse(resp));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Receive a raw message envelope
    pub async fn recv(&mut self) -> RdeResult<Message> {
        // Read message length (4 bytes)
        let mut len_buf = [0u8; 4];
        self.stream
            .read_exact(&mut len_buf)
            .await
            .map_err(RdeError::Io)?;
        let len = u32::from_le_bytes(len_buf) as usize;

        // Read the message
        let mut buf = vec![0u8; len];
        self.stream.read_exact(&mut buf).await?;

        let msg: Message = serde_json::from_slice(&buf)
            .map_err(|e| RdeError::Ipc(IpcError::InvalidArgs(e.to_string())))?;
        tracing::trace!("📥 Received: {:?}", msg);

        Ok(msg)
    }

    /// Receive a message with a timeout
    pub async fn recv_timeout(&mut self, duration: std::time::Duration) -> RdeResult<Message> {
        tokio::time::timeout(duration, self.recv())
            .await
            .map_err(|_| RdeError::Socket("Timeout receiving message".to_string()))?
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::message::{
        AckResponse, GetStatusRequest, RegisterRequest, StatusResponse,
        types::{ServiceId, ServiceInfo, ServiceStatus},
    };
    use rde_core::logger::LogLevel;
    use std::time::SystemTime;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_ipc_server_client_communication() -> RdeResult<()> {
        // Create an isolated runtime environment for XDG_RUNTIME_DIR
        let temp_dir = tempdir()?;
        unsafe {
            std::env::set_var("XDG_RUNTIME_DIR", temp_dir.path());
        }

        // create the logger
        let log_dir = tempdir().unwrap().path().to_path_buf();
        let service_name = "rde-test";
        let logger = Logger::new(LogLevel::Info, log_dir, service_name);
        logger.init()?;

        // Initialize IPC Server
        let server = IpcServer::new(logger)?;
        let socket_path = server.socket_path().clone();

        // Spawn task to accept and handle connection on server side
        let server_handle = tokio::spawn(async move {
            let mut client = server.accept_client().await.unwrap();

            // 1. Receive registration request from client
            let msg = client.recv().await.unwrap();
            if let MessagePayload::ServiceRequest(ServiceRequest::Register(reg)) = msg.payload {
                assert_eq!(reg.name, "test-service");
                assert_eq!(reg.pid, 1234);
                assert_eq!(reg.version, "0.1.0");
            } else {
                panic!("Expected MessagePayload::ServiceRequest(ServiceRequest::Register)");
            }

            // Send back register acknowledgment
            let response = DaemonResponse::RegisterAck(AckResponse {
                success: true,
                reason: Some("Registered".to_string()),
            });
            client.send_daemon_response(response).await.unwrap();

            // 2. Server sends a DaemonRequest::HealthCheck liveness check
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

            // 3. Server receives ServiceRequest::GetStatus status query
            let msg = client.recv().await.unwrap();
            if let MessagePayload::ServiceRequest(ServiceRequest::GetStatus(req)) = msg.payload {
                assert_eq!(req.name, "test-service");
            } else {
                panic!("Expected ServiceRequest::GetStatus");
            }

            // Server responds with ServiceResponse::Status
            let status = ServiceResponse::Status(StatusResponse {
                service: ServiceInfo {
                    id: ServiceId {
                        name: "test-service".to_string(),
                        pid: 1234,
                    },
                    status: ServiceStatus::Running,
                    uptime: Some(SystemTime::now()),
                    restart_count: 0,
                    version: "0.1.0".to_string(),
                },
            });
            client.send_service_response(status).await.unwrap();

            server.shutdown().unwrap();
        });

        // Connect client
        let mut client = IpcClient::connect(&socket_path).await?;

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
            panic!("Expected ServiceResponse::RegisterAck");
        }

        // 2. Receive DaemonRequest::HealthCheck liveness check
        let msg = client.recv().await?;
        assert!(matches!(
            msg.payload,
            MessagePayload::DaemonRequest(DaemonRequest::HealthCheck)
        ));

        // Send ServiceResponse::Alive liveness acknowledgment
        client.send_service_response(ServiceResponse::Alive).await?;

        // 3. Send ServiceRequest::GetStatus status query
        client
            .send_service_requst(ServiceRequest::GetStatus(GetStatusRequest {
                name: "test-service".to_string(),
            }))
            .await?;

        // Receive status response
        let msg = client.recv().await?;
        if let MessagePayload::ServiceResponse(ServiceResponse::Status(status)) = msg.payload {
            assert_eq!(status.service.id.name, "test-service");
            assert_eq!(status.service.status, ServiceStatus::Running);
        } else {
            panic!("Expected ServiceResponse::Status");
        }

        // Wait for server task to finish
        server_handle.await.unwrap();

        Ok(())
    }
}
