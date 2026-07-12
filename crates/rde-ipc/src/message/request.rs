//! Request messages (client → server)

use super::types::ServiceStatus;
use serde::{Deserialize, Serialize};

/// Contains all requests that one daemon could send to a service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DaemonRequest {
    /// Check if a Service is alive
    HealthCheck,

    /// Tell the daemon to shutdown
    Shutdown {
        service_name: String,
        reason: Option<String>,
    },
}

/// Contains all requests that one service could send to the daemon
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ServiceRequest {
    /// Register a service
    Register(RegisterRequest),

    /// Deregister a service
    Deregister { pid: u32, name: String },

    /// Get service status
    GetStatus(GetStatusRequest),

    /// Send status update
    StatusUpdate(StatusUpdateRequest),
}

/// Register a service
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterRequest {
    pub name: String,
    pub pid: u32,
    pub version: String,
    pub capabilities: Vec<String>,
}

/// Get service status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetStatusRequest {
    pub name: String,
}

/// Status update
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusUpdateRequest {
    pub status: ServiceStatus,
    pub message: Option<String>,
}
