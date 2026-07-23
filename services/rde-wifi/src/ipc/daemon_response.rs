//! # Daemon Response Handler Module
//!
//! Processes acknowledgment and response messages received from `rde-daemon`.
//!
//! ## Features
//! - Supervisor `RegisterAck` registration outcome handling
//! - Logging and connection verification state updates
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
    /// - `_client`: Active `IpcClient` socket connection.
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
                    tracing::info!("Successfully registered with Daemon");
                } else {
                    tracing::error!("Registration failed: {:?}", ack.reason);
                }
            }
        }
        Ok(())
    }
}
