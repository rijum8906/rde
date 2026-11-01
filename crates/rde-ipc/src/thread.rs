//! # Supervision Task Handle
//!
//! Handle to the supervision task a service spawns to talk to `rde-daemon`.
//!
//! # Layers
//! - [`IpcThread`]: command channel, join handle, and cancellation token
//!
//! # Lifecycle
//! The service stores this handle, asks the task to stop through [`IpcThread::tx`]
//! and [`IpcThread::cancellation_token`], then joins [`IpcThread::handle`] with
//! a bounded timeout during shutdown.

use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use crate::IpcCommand;

/// Owned handle to a running supervision task.
///
/// Every field is public because services construct the handle directly from
/// the pieces they created while spawning the task.
pub struct IpcThread {
    /// Channel used to send administrative commands to the task.
    pub tx: mpsc::Sender<IpcCommand>,

    /// Join handle of the spawned task.
    pub handle: tokio::task::JoinHandle<()>,

    /// Token that cancels the task's `select!` loop.
    pub cancellation_token: CancellationToken,
}
