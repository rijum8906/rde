//! # Daemon Messages
//!
//! Message types owned by the daemon side of the supervision socket.
//!
//! # Direction
//! - [`DaemonRequest`]: daemon -> service
//! - [`DaemonResponse`]: daemon -> service replies
//! - [`AckResponse`]: acknowledgement payload shared by both sides

use bincode::{Decode, Encode};

// =============================
// === Daemon -> Service =======
// =============================

/// Request the daemon sends to a supervised service.
#[derive(Debug, Clone, Encode, Decode)]
pub enum DaemonRequest {
    /// Liveness probe; the service answers with `ServiceResponse::Alive`.
    HealthCheck,

    /// Ask the service to report the status it currently holds.
    GetStatus(GetStatusRequest),

    /// Ask the service to shut down gracefully.
    Shutdown {
        /// Name of the service the request is addressed to.
        service_name: String,

        /// Optional human-readable reason, logged by the service.
        reason: Option<String>,
    },
}

/// Payload of [`DaemonRequest::GetStatus`].
#[derive(Debug, Clone, Encode, Decode)]
pub struct GetStatusRequest {
    /// Name the service registered under.
    pub name: String,
}

// =============================
// === Daemon -> Service =======
// =============================

/// Reply the daemon sends back to a service.
#[derive(Debug, Clone, Encode, Decode)]
pub enum DaemonResponse {
    /// Registration acknowledged.
    RegisterAck(AckResponse),

    /// Generic success for commands that return no data.
    Success,
}

/// Outcome of a daemon-side operation, such as the registration handshake.
#[derive(Debug, Clone, PartialEq, Eq, Encode, Decode)]
pub struct AckResponse {
    /// Whether the operation succeeded.
    pub success: bool,

    /// Rejection reason, set when `success` is `false`.
    pub reason: Option<String>,
}

impl AckResponse {
    /// Builds an acknowledgement with an explicit outcome.
    ///
    /// # Parameters
    /// - `success`: whether the operation succeeded
    /// - `reason`: optional detail, typically a rejection reason
    pub fn new(success: bool, reason: Option<String>) -> Self {
        Self { success, reason }
    }

    /// Builds a successful acknowledgement without a reason.
    pub fn success() -> Self {
        Self {
            success: true,
            reason: None,
        }
    }

    /// Builds a failed acknowledgement carrying `reason`.
    ///
    /// # Parameters
    /// - `reason`: explanation reported to the peer
    pub fn failure(reason: impl Into<String>) -> Self {
        Self {
            success: false,
            reason: Some(reason.into()),
        }
    }
}
