use std::path::PathBuf;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};

use rde_core::{
    errors::{RdeError, RdeResult, ipc::IpcError},
    logger::{LogLevel, Logger},
    utils::logger::init_log_dir,
};

use crate::message::{Event, Message, MessagePayload, Request, Response};

// =============================
// ======= Socket Server =========
// =============================

/// IPC Server: A socket server that listens on a Unix socket
/// and helps in communication between services.
///
/// # SECURITY
/// - Socket file permissions are set to `0o600` (owner read/write only) to restrict access.
/// - Parent directory permissions must be `0o700` (owner read/write/execute only).
///
/// # NOTE
/// - Communicates asynchronously using Tokio's Unix domain sockets.
///
/// # TODO
/// - Implement connection rate-limiting to prevent potential Denial of Service (DoS) attacks.
pub struct IpcServer {
    pub listener: UnixListener,
    logger: Logger,
    socket_path: PathBuf,
}

impl IpcServer {
    pub fn new() -> RdeResult<Self> {
        // create the logger
        let base_log_dir = init_log_dir()?;
        let log_dir = base_log_dir.join("ipc");
        let service_name = "rde-ipc";

        let logger = Logger::new(LogLevel::Info, log_dir, service_name);
        logger.init()?;

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

    pub fn logger(&self) -> &Logger {
        &self.logger
    }
}

// ============================================
// SOCKET CLIENT (Service Side)
// ============================================

/// IPC Client: Connects to the daemon's supervision socket.
///
/// # SECURITY
/// - Ensure the client validates that it is connecting to the correct socket path owned by the daemon.
///
/// # NOTE
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
    pub async fn send_request(&mut self, req: Request) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::Request(req));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send a response payload (automatically wrapped in a Message envelope)
    pub async fn send_response(&mut self, resp: Response) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::Response(resp));
        let id = msg.message_id;
        self.send(&msg).await?;
        Ok(id)
    }

    /// Send an event payload (automatically wrapped in a Message envelope)
    pub async fn send_event(&mut self, evt: Event) -> RdeResult<u64> {
        let msg = Message::new(MessagePayload::Event(evt));
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
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_ipc_server_client_communication() -> RdeResult<()> {
        // Create an isolated runtime environment for XDG_RUNTIME_DIR
        let temp_dir = tempdir()?;
        unsafe {
            std::env::set_var("XDG_RUNTIME_DIR", temp_dir.path());
        }

        // Initialize IPC Server
        let server = IpcServer::new()?;
        let socket_path = server.socket_path().clone();

        // Spawn task to accept and handle connection on server side
        let server_handle = tokio::spawn(async move {
            let mut client = server.accept_client().await.unwrap();

            // Receive request from client
            let msg = client.recv().await.unwrap();

            // Verify message structure
            if let MessagePayload::Request(Request::Register(reg)) = msg.payload {
                assert_eq!(reg.name, "test-service");
                assert_eq!(reg.pid, 1234);
                assert_eq!(reg.version, "0.1.0");
            } else {
                panic!("Expected MessagePayload::Request(Request::Register)");
            }

            // Send back register acknowledgment
            let response = Response::register_ack(true, "Registered", "test-service-123");
            client.send_response(response).await.unwrap();

            server.shutdown().unwrap();
        });

        // Connect client
        let mut client = IpcClient::connect(&socket_path).await?;

        // Send registration request
        let request = Request::register("test-service", 1234, "0.1.0");
        client.send_request(request).await?;

        // Receive response
        let response = client.recv().await?;
        if let MessagePayload::Response(Response::RegisterAck(ack)) = response.payload {
            assert!(ack.accepted);
            assert_eq!(ack.service_id, "test-service-123");
        } else {
            panic!("Expected MessagePayload::Response(Response::RegisterAck)");
        }

        // Wait for server task to finish
        server_handle.await.unwrap();

        Ok(())
    }
}
