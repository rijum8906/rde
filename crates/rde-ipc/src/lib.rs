//! # RDE Inter-Process Communication

pub mod error;
mod ipc_command;
pub mod message;
pub mod socket;
pub mod thread;

pub use crate::ipc_command::IpcCommand;
pub use crate::socket::{IpcServer, UnixIpcClient};
pub use crate::thread::IpcThread;
