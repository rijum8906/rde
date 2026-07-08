pub mod ipc;

// crates/rde-core/src/error.rs
use thiserror::Error;

use crate::errors::ipc::IpcError;

#[derive(Error, Debug)]
pub enum RdeError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Config error: {0}")]
    Config(String),

    #[error("IPC error: {0}")]
    Ipc(#[from] IpcError),

    #[error("Service error: {0}")]
    Service(String),
}

// Custom Result type for library crates
pub type RdeResult<T> = std::result::Result<T, RdeError>;
