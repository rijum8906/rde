//! # IPC Message Definitions
pub mod daemon;
pub mod error;
pub mod protocol;
pub mod service;
pub mod types;

pub use daemon::{AckResponse, DaemonRequest, DaemonResponse, GetStatusRequest};
pub use error::MessageError;
pub use protocol::*;
pub use service::{RegisterRequest, ServiceRequest, ServiceResponse, StatusUpdateRequest};
pub use types::*;

use bincode::{Decode, Encode};
use std::time::{SystemTime, UNIX_EPOCH};

const MAX_PAYLOAD_BYTES: usize = 64 * 1024 * 1024;

#[derive(Debug, Clone, Encode, Decode)]
pub struct Message {
    pub protocol_version: u32,
    pub message_id: u64,
    pub timestamp: u64,
    pub payload: MessagePayload,
}

#[derive(Debug, Clone, Encode, Decode)]
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

    pub fn is_daemon_request(&self) -> bool {
        matches!(self.payload, MessagePayload::DaemonRequest(_))
    }
    pub fn is_daemon_response(&self) -> bool {
        matches!(self.payload, MessagePayload::DaemonResponse(_))
    }
    pub fn is_service_request(&self) -> bool {
        matches!(self.payload, MessagePayload::ServiceRequest(_))
    }
    pub fn is_service_response(&self) -> bool {
        matches!(self.payload, MessagePayload::ServiceResponse(_))
    }
    pub fn is_protocol_supported(&self) -> bool {
        self.protocol_version >= MIN_PROTOCOL_VERSION
    }

    pub fn encode(&self) -> Result<Vec<u8>, MessageError> {
        let config = bincode::config::standard();
        let encoded = bincode::encode_to_vec(self, config)?;

        if encoded.len() > MAX_PAYLOAD_BYTES {
            return Err(MessageError::PayloadTooLarge {
                max: MAX_PAYLOAD_BYTES,
                actual: encoded.len(),
            });
        }

        let len: u32 = encoded
            .len()
            .try_into()
            .map_err(|_| MessageError::PayloadTooLarge {
                max: u32::MAX as usize,
                actual: encoded.len(),
            })?;

        let mut data = Vec::with_capacity(4 + encoded.len());
        data.extend_from_slice(&len.to_be_bytes());
        data.extend_from_slice(&encoded);
        Ok(data)
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, MessageError> {
        let config = bincode::config::standard();
        let (msg, _) = bincode::decode_from_slice::<Message, _>(bytes, config)?;
        Ok(msg)
    }
}

fn generate_message_id() -> u64 {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(1);
    COUNTER.fetch_add(1, Ordering::SeqCst)
}

fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
