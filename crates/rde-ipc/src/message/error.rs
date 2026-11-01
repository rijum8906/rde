//! Message-level errors.

use thiserror::Error;

#[derive(Error, Debug)]
pub enum MessageError {
    // === Protocol & Version Errors ===
    #[error("Unsupported protocol version {0}. Please update your client.")]
    UnsupportedProtocol(u32),

    // === Framing & Payload Errors ===
    #[error("Not a daemon message: expected Daemon Message, found {0}")]
    NotADaemonMessage(String),

    #[error("Not a service message: expected Service Message, found {0}")]
    NotAServiceMessage(String),

    #[error("Missing required field: {0}")]
    MissingField(&'static str),

    // === Serialization Errors ===
    #[error("Failed to encode message: {0}")]
    Encoding(#[from] bincode::error::EncodeError),

    #[error("Failed to decode message: {0}")]
    Decoding(#[from] bincode::error::DecodeError),

    #[error("Payload exceeds maximum allowed size of {max} bytes (got {actual})")]
    PayloadTooLarge { max: usize, actual: usize },

    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    // === Routing & Service Errors ===
    #[error("Invalid service name: '{0}'")]
    InvalidServiceName(String),

    #[error("Service '{0}' is already registered")]
    ServiceAlreadyRegistered(String),

    #[error("Service '{0}' not found in the registry")]
    ServiceNotFound(String),

    #[error("Service '{0}' does not have the required capability: '{1}'")]
    MissingCapability(String, String),
}
