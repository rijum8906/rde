//! # IPC Client Contract
//!
//! Defines [`IpcClient`], the behaviour every supervision-socket peer shares, and
//! the framing and handshake helpers every implementation gets for free.

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

/// Common contract of a peer on the RDE supervision socket.
///
/// Both sides of the socket use this trait: a service connects out to
/// `rde-daemon`, while the daemon wraps every accepted connection. Implementors
/// only provide the six required operations; the typed sends, the
/// receive-with-timeout helper, and the registration handshake are default
/// methods layered on top of [`IpcClient::send`], so a test double stays small
/// while behaving like the real client.
///
/// # Implementors
/// - [`crate::socket::UnixIpcClient`]: the production Unix-domain-socket client.
/// - Test doubles: implement the required methods only, then use the default
///   helpers to assert the frames a service would send.
///
/// # Examples
/// ```no_run
/// use std::{path::Path, time::Duration};
/// use rde_ipc::{IpcClient, socket::UnixIpcClient};
///
/// # async fn example() -> rde_ipc::error::IpcResult<()> {
/// let mut client = UnixIpcClient::default();
/// client
///     .connect_with_retry(Path::new("/run/user/1000/rde/rde.sock"), 5, Duration::from_secs(2))
///     .await?;
/// client.register("theme", "0.1.0", &["dynamic-palettes"]).await?;
/// # Ok(())
/// # }
/// ```
#[async_trait]
pub trait IpcClient: Send + Sync {
    // ─── Required ──────────────────────────────────────────────────────────

    /// Opens a connection to the supervision socket at `socket_path`.
    ///
    /// # Parameters
    /// - `socket_path`: path of the socket owned by `rde-daemon`
    ///
    /// # Errors
    /// Returns [`IpcError::Connection`] when the socket is missing, not a
    /// socket, or rejected by the peer.
    ///
    /// # Behavior
    /// Replaces any connection the client already holds.
    async fn connect(&mut self, socket_path: &Path) -> IpcResult<()>;

    /// Returns whether a connection is currently open.
    fn is_connected(&self) -> bool;

    /// Returns the path this client connected to, if it opened the connection.
    ///
    /// # Returns
    /// `Some(path)` for a client that connected itself, and `None` for a client
    /// built from an already accepted stream, where the peer chose the address.
    fn socket_path(&self) -> Option<&Path>;

    /// Closes the connection and releases the resources behind it.
    ///
    /// # Errors
    /// Returns [`IpcError::Io`] when the shutdown call fails. A closed socket
    /// never stops the client: the error is reported and the connection is
    /// dropped either way.
    ///
    /// # Behavior
    /// Idempotent: disconnecting an idle client succeeds without touching the
    /// socket.
    async fn disconnect(&mut self) -> IpcResult<()>;

    /// Writes one message frame.
    ///
    /// # Parameters
    /// - `message`: envelope to encode and write
    ///
    /// # Returns
    /// The [`Message::message_id`] of the frame that was written.
    ///
    /// # Errors
    /// Returns [`IpcError::NotConnected`] when there is no connection, and
    /// [`IpcError::Io`] when the frame cannot be written or flushed.
    async fn send(&mut self, message: &Message) -> IpcResult<u64>;

    /// Reads the next message frame.
    ///
    /// # Errors
    /// Returns [`IpcError::NotConnected`] when there is no connection,
    /// [`IpcError::Io`] when the peer closes mid-frame, and
    /// [`IpcError::InvalidArgs`] when a payload cannot be decoded.
    async fn recv(&mut self) -> IpcResult<Message>;

    // ─── Provided ──────────────────────────────────────────────────────────

    /// Connects, retrying with a fixed delay between attempts.
    ///
    /// # Parameters
    /// - `socket_path`: path of the socket owned by `rde-daemon`
    /// - `attempts`: number of attempts; a value of zero still makes one
    /// - `delay`: time to wait between two attempts
    ///
    /// # Returns
    /// `Ok(())` as soon as an attempt connects.
    ///
    /// # Errors
    /// Returns the error of the final attempt when every attempt fails. A
    /// daemon that starts later is the common case, so failures are logged at
    /// warning level rather than reported as fatal.
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

    /// Reads the next frame, giving up after `timeout`.
    ///
    /// # Parameters
    /// - `timeout`: maximum time to wait for a complete frame
    ///
    /// # Errors
    /// Returns [`IpcError::Timeout`] when no frame arrives in time, and
    /// otherwise propagates the errors of [`IpcClient::recv`].
    async fn recv_timeout(&mut self, timeout: Duration) -> IpcResult<Message> {
        tokio::time::timeout(timeout, self.recv())
            .await
            .map_err(|_| IpcError::Timeout(timeout))?
    }

    /// Sends a service-to-daemon request.
    ///
    /// # Returns
    /// The id of the frame that was written.
    async fn send_service_request(&mut self, request: ServiceRequest) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::ServiceRequest(request));
        self.send(&message).await
    }

    /// Sends a service-to-daemon response.
    ///
    /// # Returns
    /// The id of the frame that was written.
    async fn send_service_response(&mut self, response: ServiceResponse) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::ServiceResponse(response));
        self.send(&message).await
    }

    /// Sends a daemon-to-service request.
    ///
    /// # Returns
    /// The id of the frame that was written.
    async fn send_daemon_request(&mut self, request: DaemonRequest) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::DaemonRequest(request));
        self.send(&message).await
    }

    /// Sends a daemon-to-service response.
    ///
    /// # Returns
    /// The id of the frame that was written.
    async fn send_daemon_response(&mut self, response: DaemonResponse) -> IpcResult<u64> {
        let message = Message::new(MessagePayload::DaemonResponse(response));
        self.send(&message).await
    }

    /// Announces this service to the supervisor.
    ///
    /// # Parameters
    /// - `name`: service name the supervisor supervises and restarts
    /// - `version`: version of the running binary
    /// - `capabilities`: feature flags advertised to the supervisor
    ///
    /// # Returns
    /// The id of the registration frame, for correlating the `RegisterAck`.
    ///
    /// # Behavior
    /// The process id is filled in from the running process, so callers cannot
    /// announce the wrong one.
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

    /// Tells the supervisor this service is going away.
    ///
    /// # Parameters
    /// - `name`: name the service registered under
    /// - `pid`: process id the service registered with
    ///
    /// # Returns
    /// The id of the deregistration frame.
    async fn deregister(&mut self, name: &str, pid: u32) -> IpcResult<u64> {
        let request = ServiceRequest::Deregister {
            name: name.to_string(),
            pid,
        };

        self.send_service_request(request).await
    }
}

#[cfg(test)]
mod tests {
    use std::{
        path::{Path, PathBuf},
        sync::Mutex,
        time::Duration,
    };

    use super::*;
    use crate::message::ServiceStatus;

    /// Test double that records frames and answers from a scripted queue.
    ///
    /// It implements only the required methods, which proves the provided
    /// helpers are usable without reimplementing the framing.
    #[derive(Default)]
    struct FakeClient {
        connected: bool,
        path: Option<PathBuf>,
        sent: Mutex<Vec<Message>>,
        incoming: Mutex<Vec<Message>>,

        /// Number of `connect` calls that must still fail.
        remaining_failures: Mutex<u32>,

        /// Number of `connect` calls received.
        connect_calls: Mutex<u32>,
    }

    impl FakeClient {
        /// Returns the payload of the frame at `index`.
        fn sent_payload(&self, index: usize) -> MessagePayload {
            self.sent.lock().expect("sent frames")[index]
                .payload
                .clone()
        }

        /// Returns how many connect attempts were made.
        fn connect_attempts(&self) -> u32 {
            *self.connect_calls.lock().expect("attempts")
        }
    }

    #[async_trait]
    impl IpcClient for FakeClient {
        async fn connect(&mut self, socket_path: &Path) -> IpcResult<()> {
            *self.connect_calls.lock().expect("attempts") += 1;

            let mut remaining = self.remaining_failures.lock().expect("attempts");
            if *remaining > 0 {
                *remaining -= 1;
                return Err(IpcError::Connection {
                    message: "socket not ready".to_string(),
                    reason: "test double".to_string(),
                });
            }

            self.connected = true;
            self.path = Some(socket_path.to_path_buf());
            Ok(())
        }

        fn is_connected(&self) -> bool {
            self.connected
        }

        fn socket_path(&self) -> Option<&Path> {
            self.path.as_deref()
        }

        async fn disconnect(&mut self) -> IpcResult<()> {
            self.connected = false;
            self.path = None;
            Ok(())
        }

        async fn send(&mut self, message: &Message) -> IpcResult<u64> {
            if !self.connected {
                return Err(IpcError::NotConnected);
            }

            self.sent.lock().expect("sent frames").push(message.clone());
            Ok(message.message_id)
        }

        async fn recv(&mut self) -> IpcResult<Message> {
            if !self.connected {
                return Err(IpcError::NotConnected);
            }

            if let Some(message) = self.incoming.lock().expect("incoming frames").pop() {
                return Ok(message);
            }

            // Nothing queued: behave like a peer that has nothing to say yet,
            // so the caller's own deadline is what ends the wait.
            tokio::time::sleep(Duration::from_millis(500)).await;
            Err(IpcError::NotConnected)
        }
    }

    /// Builds a connected double with one scripted incoming frame.
    fn connected_double(incoming: Vec<Message>) -> FakeClient {
        FakeClient {
            connected: true,
            path: Some(PathBuf::from("/tmp/rde-test.sock")),
            incoming: Mutex::new(incoming),
            ..FakeClient::default()
        }
    }

    #[tokio::test]
    async fn typed_sends_preserve_the_payload_and_return_the_frame_id() {
        let mut client = connected_double(Vec::new());

        let id = client
            .send_service_request(ServiceRequest::StatusUpdate(
                crate::message::StatusUpdateRequest {
                    status: ServiceStatus::Running,
                    message: None,
                },
            ))
            .await
            .expect("status update must be written");

        assert!(matches!(
            client.sent_payload(0),
            MessagePayload::ServiceRequest(ServiceRequest::StatusUpdate(_))
        ));
        assert_eq!(
            id,
            client.sent.lock().expect("sent frames")[0].message_id,
            "the returned id must be the id of the written frame"
        );
    }

    #[tokio::test]
    async fn registration_fills_in_the_running_process_id() {
        let mut client = connected_double(Vec::new());

        client
            .register("wifi", "1.2.3", &["nm-dbus"])
            .await
            .expect("registration must be written");

        let MessagePayload::ServiceRequest(ServiceRequest::Register(request)) =
            client.sent_payload(0)
        else {
            panic!("registration must be a ServiceRequest::Register frame");
        };

        assert_eq!(request.name, "wifi");
        assert_eq!(request.version, "1.2.3");
        assert_eq!(request.pid, std::process::id());
        assert_eq!(request.capabilities, vec!["nm-dbus".to_string()]);
    }

    #[tokio::test]
    async fn deregistration_carries_the_identity_the_supervisor_knows() {
        let mut client = connected_double(Vec::new());

        client
            .deregister("wifi", 4321)
            .await
            .expect("deregistration must be written");

        let MessagePayload::ServiceRequest(ServiceRequest::Deregister { name, pid }) =
            client.sent_payload(0)
        else {
            panic!("deregistration must be a ServiceRequest::Deregister frame");
        };

        assert_eq!(name, "wifi");
        assert_eq!(pid, 4321);
    }

    #[tokio::test]
    async fn connect_with_retry_keeps_trying_until_the_socket_answers() {
        let mut client = FakeClient {
            remaining_failures: Mutex::new(2),
            ..FakeClient::default()
        };

        client
            .connect_with_retry(Path::new("/tmp/rde-test.sock"), 5, Duration::from_millis(1))
            .await
            .expect("the third attempt must connect");

        assert_eq!(client.connect_attempts(), 3, "two failures then a success");
        assert!(client.is_connected());
        assert_eq!(client.socket_path(), Some(Path::new("/tmp/rde-test.sock")));
    }

    #[tokio::test]
    async fn connect_with_retry_reports_the_last_failure_without_panicking() {
        let mut client = FakeClient {
            remaining_failures: Mutex::new(10),
            ..FakeClient::default()
        };

        // A zero attempt count still makes one attempt rather than failing blind.
        let error = client
            .connect_with_retry(Path::new("/tmp/rde-test.sock"), 0, Duration::from_millis(1))
            .await
            .expect_err("a socket that never answers must fail");

        assert!(matches!(error, IpcError::Connection { .. }), "{error:?}");
        assert_eq!(
            client.connect_attempts(),
            1,
            "exactly one attempt must be made"
        );
        assert!(!client.is_connected());
    }

    #[tokio::test]
    async fn recv_timeout_gives_up_with_a_timeout_error() {
        // A connected client with an empty queue never yields a frame.
        let mut client = connected_double(Vec::new());

        let error = client
            .recv_timeout(Duration::from_millis(10))
            .await
            .expect_err("an empty queue must time out");

        assert!(matches!(error, IpcError::Timeout(_)), "{error:?}");
    }

    #[tokio::test]
    async fn recv_timeout_returns_a_frame_that_arrives_in_time() {
        let frame = Message::new(MessagePayload::DaemonRequest(DaemonRequest::HealthCheck));
        let mut client = connected_double(vec![frame.clone()]);

        let received = client
            .recv_timeout(Duration::from_secs(5))
            .await
            .expect("the queued frame must be returned");

        assert_eq!(received.message_id, frame.message_id);
    }
}
