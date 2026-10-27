//! # IPC Errors
//!
//! Domain errors reported by the supervision socket layer and its clients.

use std::time::Duration;

/// Failures a peer can hit while talking over the supervision socket.
#[derive(Debug, thiserror::Error)]
pub enum IpcError {
    #[error("Socket error: {0}")]
    Socket(String),

    /// A read or write exceeded the caller's deadline.
    #[error("Timed out after {0:?}")]
    Timeout(Duration),

    #[error("Connection error: {message} ({reason})")]
    Connection { message: String, reason: String },

    #[error("Not connected to IPC")]
    NotConnected,

    #[error("Failed to send message")]
    FailedToSendMessage,

    #[error("Invalid arguments: {0}")]
    InvalidArgs(String),

    #[error("Io error: {0}")]
    Io(#[from] std::io::Error),
}

pub type IpcResult<T> = Result<T, IpcError>;
