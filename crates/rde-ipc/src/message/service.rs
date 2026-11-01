//! # Service Messages
//!
//! Message types owned by the service side of the supervision socket.
//!
//! # Direction
//! - [`ServiceRequest`]: service -> daemon
//! - [`ServiceResponse`]: service -> daemon replies

use bincode::{Decode, Encode};

use super::{daemon::AckResponse, types::ServiceStatus};

// =============================
// === Service -> Daemon =======
// =============================

/// Request a service sends to the daemon.
#[derive(Debug, Clone, Encode, Decode)]
pub enum ServiceRequest {
    /// Announce this service to the supervisor.
    Register(RegisterRequest),

    /// Tell the supervisor the service is going away.
    Deregister {
        /// Process id the service registered with.
        pid: u32,

        /// Name the service registered under.
        name: String,
    },

    /// Push a status transition to the supervisor.
    StatusUpdate(StatusUpdateRequest),
}

/// Payload of [`ServiceRequest::Register`].
#[derive(Debug, Clone, Encode, Decode)]
pub struct RegisterRequest {
    /// Name the supervisor supervises and restarts.
    pub name: String,

    /// Process id of the running service.
    pub pid: u32,

    /// Version of the running binary.
    pub version: String,

    /// Feature flags advertised to the supervisor.
    pub capabilities: Vec<String>,
}

/// Payload of [`ServiceRequest::StatusUpdate`].
#[derive(Debug, Clone, Encode, Decode)]
pub struct StatusUpdateRequest {
    /// Status the service is transitioning to.
    pub status: ServiceStatus,

    /// Optional detail, such as a degradation reason.
    pub message: Option<String>,
}

// =============================
// === Service -> Daemon =======
// =============================

/// Reply a service sends back to the daemon.
#[derive(Debug, Clone, Encode, Decode)]
pub enum ServiceResponse {
    /// Status snapshot reported by the service.
    Status(ServiceStatus),

    /// Shutdown acknowledged.
    ShutdownAck(AckResponse),

    /// Liveness confirmation for a health check.
    Alive,
}
