//! # Daemon Response Handler
//!
//! Processes responses from the daemon supervisor to previously sent requests.
//! Currently handles registration acknowledgment from the daemon.
//!
//! ## Response Types
//! - `RegisterAck`: Confirmation of service registration (success/failure with reason)
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
use rde_ipc::{message::DaemonResponse, socket::IpcClient};
use tracing::{error, info};

use crate::app::handler::Handler;

impl Handler {
    /// Processes responses received back from the daemon supervisor.
    ///
    /// # Workflow
    /// 1. Match response type
    /// 2. For RegisterAck:
    ///    - If success: Log info message
    ///    - If failure: Log error with reason
    /// 3. Return Ok (non-fatal errors logged, not propagated)
    ///
    /// # Current Implementation
    /// Only handles `RegisterAck` responses. Other response types
    /// are ignored (no warning as they're not currently expected).
    ///
    /// # Errors
    /// Never returns errors (all conditions logged and handled gracefully)
    ///
    /// # Parameters
    /// - `response`: Response enum variant from daemon
    /// - `_client`: IPC client reference (unused, kept for API consistency)
    pub async fn handle_daemon_response(
        &mut self,
        response: DaemonResponse,
        _client: &mut IpcClient,
    ) -> RdeResult<()> {
        match response {
            DaemonResponse::RegisterAck(ack) => {
                if ack.success {
                    info!(
                        "Successfully registered with Daemon supervisor (PID: {})",
                        std::process::id()
                    );
                } else {
                    error!("Registration with Daemon failed - Reason: {:?}", ack.reason);
                }
            }
        }
        Ok(())
    }
}
