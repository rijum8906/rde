//! Request messages (client → server)

use super::types::ServiceStatus;
use serde::{Deserialize, Serialize};

/// All possible requests
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Request {
    /// Register a service
    Register(RegisterRequest),

    /// Health check response (Alive)
    Heartbeat(HeartbeatRequest),

    /// Get service status
    GetStatus(GetStatusRequest),

    /// Get all services status
    ListServices(ListServicesRequest),

    /// Request shutdown
    Shutdown(ShutdownRequest),

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

/// Heartbeat (Alive)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HeartbeatRequest {
    pub timestamp: u64, // Unix timestamp
    pub metrics: Option<ServiceMetrics>,
}

/// Service metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceMetrics {
    pub cpu_usage: Option<f32>,
    pub memory_usage: Option<u64>,
    pub uptime_seconds: Option<u64>,
}

/// Get service status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetStatusRequest {
    pub name: String,
}

/// List all services
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListServicesRequest {
    pub include_metrics: bool,
}

/// Request shutdown
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShutdownRequest {
    pub reason: Option<String>,
}

/// Status update
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusUpdateRequest {
    pub status: ServiceStatus,
    pub message: Option<String>,
}

impl Request {
    pub fn register(name: &str, pid: u32, version: &str) -> Self {
        Self::Register(RegisterRequest {
            name: name.to_string(),
            pid,
            version: version.to_string(),
            capabilities: vec![],
        })
    }

    pub fn heartbeat() -> Self {
        Self::Heartbeat(HeartbeatRequest {
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
            metrics: None,
        })
    }

    pub fn get_status(name: &str) -> Self {
        Self::GetStatus(GetStatusRequest {
            name: name.to_string(),
        })
    }
}
