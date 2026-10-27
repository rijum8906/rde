//! # Inter-Process Communication (IPC) Module
//!
//! Handles Unix domain socket communication between `rde-wifi` service and `rde-daemon` supervisor.
//! Provides health check responses, status updates, registration handshakes, and graceful shutdowns.
//!
//! ## Features
//! - Daemon request and response message handlers
//! - Asynchronous IPC socket loop runner
//!
//! ## Related
//! - [`crate::ipc::handler`]
//! - [`crate::ipc::daemon_request`]
//! - [`crate::ipc::daemon_response`]
//! - [`rde_ipc`](../../crates/rde-ipc)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod daemon_request;
pub mod daemon_response;
pub mod handler;

/// Maps a supervision-socket failure onto the service's domain error.
///
/// # Parameters
/// - `error`: transport error reported by [`rde_ipc::client::IpcClient`]
///
/// # Returns
/// [`RdeError::Socket`] carrying the transport message, mirroring how every
/// other RDE service reports supervision failures.
pub(crate) fn socket_error(error: rde_ipc::error::IpcError) -> rde_core::errors::RdeError {
    rde_core::errors::RdeError::Socket(error.to_string())
}
