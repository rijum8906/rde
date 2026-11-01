//! # IPC Commands
//!
//! Administrative commands a service sends to its own supervision task.
//!
//! # Layers
//! - [`IpcCommand`]: the operations the supervision loop understands

/// Command delivered to a supervision task through its channel.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IpcCommand {
    /// Stop the supervision loop and disconnect from the daemon.
    Shutdown,
}
