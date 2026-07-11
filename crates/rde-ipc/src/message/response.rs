//! Response messages (server → client)

use super::types::{ErrorDetails, ServiceInfo};
use serde::{Deserialize, Serialize};

/// All possible responses
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum Response {
    /// Successful response
    Success(SuccessResponse),

    /// Error response
    Error(ErrorResponse),

    /// Registration acknowledged
    RegisterAck(RegisterAckResponse),

    /// Service status response
    Status(StatusResponse),

    /// List of services
    ServiceList(ServiceListResponse),

    /// Shutdown acknowledged
    ShutdownAck(ShutdownAckResponse),
}

/// Success response (generic)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SuccessResponse {
    pub message: String,
    pub data: Option<serde_json::Value>,
}

/// Error response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorResponse {
    pub error: ErrorDetails,
}

/// Registration acknowledgment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterAckResponse {
    pub accepted: bool,
    pub message: String,
    pub service_id: String,
}

/// Status response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusResponse {
    pub service: ServiceInfo,
}

/// Service list response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceListResponse {
    pub services: Vec<ServiceInfo>,
    pub count: usize,
}

/// Shutdown acknowledgment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShutdownAckResponse {
    pub accepted: bool,
    pub message: String,
}

impl Response {
    pub fn success(message: &str) -> Self {
        Self::Success(SuccessResponse {
            message: message.to_string(),
            data: None,
        })
    }

    pub fn error(code: u32, message: &str) -> Self {
        Self::Error(ErrorResponse {
            error: ErrorDetails {
                code,
                message: message.to_string(),
                details: None,
            },
        })
    }

    pub fn register_ack(accepted: bool, message: &str, service_id: &str) -> Self {
        Self::RegisterAck(RegisterAckResponse {
            accepted,
            message: message.to_string(),
            service_id: service_id.to_string(),
        })
    }
}
