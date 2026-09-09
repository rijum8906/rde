//! # Message Handler Module
//!
//! Routes and dispatches daemon supervisor messages to appropriate handlers.
//! Manages communication with the rde-daemon for service lifecycle coordination.
//!
//! ## Message Types
//! - **DaemonRequest**: Incoming requests from supervisor (HealthCheck, GetStatus, Shutdown)
//! - **DaemonResponse**: Responses to previously sent requests (RegisterAck)
//!
//! ## Workflow
//! 1. Receive message from IPC socket
//! 2. Route to appropriate handler based on message type
//! 3. Generate response if needed
//! 4. Send response back to daemon
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::errors::RdeResult;
use rde_ipc::{
    message::{Message, MessagePayload},
    socket::IpcClient,
};
use tracing::{debug, warn};

pub mod request;
pub mod response;

/// Message handler for daemon supervisor communication.
///
/// Encapsulates the service name and provides methods to route and process
/// messages received from the daemon supervisor via Unix domain socket.
///
/// # Fields
/// - `service_name`: Identifier for logging and message context (e.g., "brightness")
#[derive(Debug)]
pub struct Handler {
    /// Service name for logging and diagnostics
    pub service_name: String,
}

impl Handler {
    /// Creates a new `Handler` instance.
    ///
    /// # Parameters
    /// - `service_name`: Name of this service for logging context
    pub fn new(service_name: &str) -> Self {
        Self {
            service_name: service_name.to_string(),
        }
    }

    /// Routes and handles incoming messages from the daemon supervisor.
    ///
    /// # Workflow
    /// 1. Match message payload type
    /// 2. Dispatch to appropriate handler:
    ///    - `DaemonRequest` → `handle_daemon_request()`
    ///    - `DaemonResponse` → `handle_daemon_response()`
    ///    - Other → Log warning and ignore
    /// 3. Return result from handler
    ///
    /// # Parameters
    /// - `msg`: Message received from daemon
    /// - `client`: IPC client for sending responses
    ///
    /// # Returns
    /// `Ok(())` on successful handling, `Err(RdeError)` on I/O failure
    ///
    /// # Errors
    /// Propagates I/O errors from handlers (socket send failures)
    pub async fn handle_message(&mut self, msg: Message, client: &mut IpcClient) -> RdeResult<()> {
        match msg.payload {
            MessagePayload::DaemonRequest(request) => {
                debug!("Routing DaemonRequest to handler");
                self.handle_daemon_request(request, client).await
            }
            MessagePayload::DaemonResponse(response) => {
                debug!("Routing DaemonResponse to handler");
                self.handle_daemon_response(response, client).await
            }
            _ => {
                warn!(
                    "Service received unexpected payload category from daemon: {:?}",
                    msg.payload
                );
                Ok(())
            }
        }
    }
}
