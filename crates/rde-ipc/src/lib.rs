//! # RDE Inter-Process Communication
//!
//! Framing, message types, and socket primitives shared by `rde-daemon` and the
//! services it supervises.
//!
//! # Layers
//! - [`client`]: the [`IpcClient`] contract every peer implements
//! - [`socket`]: the Unix-domain-socket server and its production client
//! - [`message`]: protocol version, request/response payloads, and envelopes
//! - [`thread`]: supervision task handle used by service runtimes

pub mod client;
pub mod error;
mod ipc_command;
pub mod message;
pub mod socket;
pub mod thread;

pub use crate::client::IpcClient;
pub use crate::ipc_command::IpcCommand;
pub use crate::socket::UnixIpcClient;
