use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum IpcError {}

#[derive(Serialize, Deserialize, Debug)]
pub enum IpcErrorCode {
    InvalidState,
    ConfigError,
    Internal,
}
