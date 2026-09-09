//! # Daemon Response Handler Module
//!
//! Processes acknowledgment and response messages received from `rde-daemon`.
//!
//! ## Features
//! - Supervisor `RegisterAck` registration outcome handling
//! - Logging and connection verification state updates
//! - Comprehensive error and success logging
//!
//! ## Related
//! - [`crate::ipc::handler::IpcHandler`]
//! - [`rde_ipc::message::DaemonResponse`](rde_ipc::message::DaemonResponse)
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

use crate::ipc::handler::IpcHandler;

impl IpcHandler {
    /// Processes response messages received back from the daemon supervisor (e.g. `RegisterAck`).
    ///
    /// # Parameters
    /// - `response`: The incoming `DaemonResponse` payload from the supervisor.
    /// - `_client`: Active `IpcClient` socket connection (reserved for future use).
    ///
    /// # Response Types
    /// - **RegisterAck**: Confirms successful service registration or reports failure reason
    ///   - Success: Logs INFO level message
    ///   - Failure: Logs ERROR level with rejection reason
    ///
    /// # Errors
    /// Returns `RdeResult::Ok(())` on successful message processing.
    pub async fn handle_daemon_response(
        response: DaemonResponse,
        _client: &mut IpcClient,
    ) -> RdeResult<()> {
        match response {
            DaemonResponse::RegisterAck(ack) => {
                if ack.success {
                    tracing::info!("Theme service successfully registered with daemon supervisor");
                } else {
                    tracing::error!(
                        "Theme service registration failed. Reason: {:?}",
                        ack.reason
                    );
                }
            }
        }
        Ok(())
    }
}
