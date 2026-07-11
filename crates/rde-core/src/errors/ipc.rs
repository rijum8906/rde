use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum IpcError {
    // invalid arguments
    #[error("invalid arguments: {0}")]
    InvalidArgs(String),
    // invalid state
    #[error("invalid state")]
    InvalidState,
    // config error
    #[error("config error")]
    ConfigError,
    // internal error
    #[error("internal error")]
    Internal,
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
pub enum IpcErrorCode {
    InvalidState,
    ConfigError,
    Internal,
}
