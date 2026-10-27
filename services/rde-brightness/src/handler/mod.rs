//! # Daemon Message Handler (`rde-brightness`)
//!
//! Routes messages received from the `rde-daemon` supervisor to the request and
//! response handlers.
//!
//! ## Features
//! - `DaemonRequest` dispatch (health checks, status queries, shutdown)
//! - `DaemonResponse` dispatch (registration acknowledgement)
//! - Warning-only handling of unexpected payload categories
//!
//! ## Related
//! - [`crate::handler::request`]: request implementation
//! - [`crate::handler::response`]: response implementation
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_ipc::client::IpcClient;
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

use rde_core::errors::RdeResult;
use rde_ipc::message::{Message, MessagePayload, ServiceStatus};
use tokio_util::sync::CancellationToken;
use tracing::debug;

pub mod request;
pub mod response;

/// Runtime state the supervision handlers may touch.
///
/// The binary entry point holds the application mutex for the whole event loop,
/// so handlers must never take that lock. This context exposes the few values
/// they need through lock-free primitives instead.
#[derive(Clone)]
pub struct SupervisionContext {
    /// Mirrors the application running flag.
    running: Arc<AtomicBool>,

    /// Cancels the application event loop on a supervisor shutdown request.
    shutdown: CancellationToken,
}

impl SupervisionContext {
    /// Creates a context over the shared application primitives.
    ///
    /// # Parameters
    /// - `running`: running flag owned by the application state
    /// - `shutdown`: cancellation token owned by the application state
    pub fn new(running: Arc<AtomicBool>, shutdown: CancellationToken) -> Self {
        Self { running, shutdown }
    }

    /// Returns the status reported to the supervisor.
    pub fn status(&self) -> ServiceStatus {
        if self.running.load(Ordering::Relaxed) {
            ServiceStatus::Running
        } else {
            ServiceStatus::Stopped
        }
    }

    /// Requests cooperative shutdown of the application event loop.
    pub fn request_shutdown(&self) {
        self.shutdown.cancel();
    }
}

/// Handles a single message from the supervisor.
///
/// # Parameters
/// - `message`: decoded message envelope
/// - `client`: connection used to answer the supervisor
/// - `context`: lock-free view of the application runtime state
///
/// # Errors
/// Propagates write failures from the request and response handlers so the
/// caller can close a dead supervision connection.
pub async fn handle_message(
    message: Message,
    client: &mut dyn IpcClient,
    context: &SupervisionContext,
) -> RdeResult<()> {
    match message.payload {
        MessagePayload::DaemonRequest(request) => {
            debug!("Routing supervisor request to handler");
            request::handle_daemon_request(request, client, context).await
        }
        MessagePayload::DaemonResponse(response) => {
            debug!("Routing supervisor response to handler");
            response::handle_daemon_response(response, client).await
        }
        payload => {
            tracing::warn!(?payload, "Ignoring unexpected message from the supervisor");
            Ok(())
        }
    }
}
