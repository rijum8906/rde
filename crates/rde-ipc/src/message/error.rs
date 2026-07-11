//! Message-level errors

use thiserror::Error;

#[derive(Error, Debug)]
pub enum MessageError {
    #[error("Invalid protocol version: {0}")]
    InvalidProtocol(u32),

    #[error("Unsupported protocol version: {0}")]
    UnsupportedProtocol(u32),

    #[error("Unknown message type: {0}")]
    UnknownMessageType(String),

    #[error("Missing required field: {0}")]
    MissingField(String),

    #[error("Invalid service name: {0}")]
    InvalidServiceName(String),

    #[error("Service already registered: {0}")]
    ServiceAlreadyRegistered(String),

    #[error("Service not found: {0}")]
    ServiceNotFound(String),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Deserialization error: {0}")]
    Deserialization(String),
}
