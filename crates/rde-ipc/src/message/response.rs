//! Response messages (server → client)

use super::types::ServiceInfo;
use serde::{Deserialize, Serialize};

/// All possible responses that a daemon could send to a service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DaemonResponse {
    /// Registration acknowledged
    /// Response on Register request
    RegisterAck(AckResponse),
}

/// All possible responses that a service could send to the daemon
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ServiceResponse {
    /// Service status response
    Status(StatusResponse),

    /// Shutdown acknowledged
    /// Response on Shutdown request
    ShutdownAck(AckResponse),

    /// Alive response (heartbeat confirmation)
    Alive,
}

/// Acknowledgement response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AckResponse {
    /// Whether the request was successful
    pub success: bool,

    /// Error message if not successful
    pub reason: Option<String>,
}

/// Status response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusResponse {
    pub service: ServiceInfo,
}

/// Shutdown acknowledgment (daemon-to-service)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShutdownAckResponse {
    pub accepted: bool,
    pub message: String,
}
