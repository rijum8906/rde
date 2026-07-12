//! IPC Message Definitions
pub mod error;
pub mod protocol;
pub mod request;
pub mod response;
pub mod types;

// Re-export
pub use error::MessageError;
pub use protocol::*;
pub use request::*;
pub use response::*;
use serde::{Deserialize, Serialize};
pub use types::*;

/// Complete message wrapper (protocol + payload)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub protocol_version: u32,
    pub message_id: u64,
    pub timestamp: u64,
    #[serde(flatten)]
    pub payload: MessagePayload,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", content = "data")]
pub enum MessagePayload {
    DaemonRequest(DaemonRequest),
    DaemonResponse(DaemonResponse),
    ServiceRequest(ServiceRequest),
    ServiceResponse(ServiceResponse),
}

impl Message {
    pub fn new(payload: MessagePayload) -> Self {
        Self {
            protocol_version: PROTOCOL_VERSION,
            message_id: generate_message_id(),
            timestamp: current_timestamp(),
            payload,
        }
    }

    /// Check if the message is a daemon request
    pub fn is_daemon_request(&self) -> bool {
        matches!(self.payload, MessagePayload::DaemonRequest(_))
    }

    /// Check if the message is a service request
    pub fn is_service_request(&self) -> bool {
        matches!(self.payload, MessagePayload::ServiceRequest(_))
    }

    /// Check if the message is a daemon response
    pub fn is_damon_response(&self) -> bool {
        matches!(self.payload, MessagePayload::DaemonResponse(_))
    }

    /// Check if the message is a service response
    pub fn is_service_response(&self) -> bool {
        matches!(self.payload, MessagePayload::ServiceResponse(_))
    }

    pub fn is_protocol_supported(&self) -> bool {
        self.protocol_version >= MIN_PROTOCOL_VERSION
    }
}

fn generate_message_id() -> u64 {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(1);
    COUNTER.fetch_add(1, Ordering::SeqCst)
}

fn current_timestamp() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
