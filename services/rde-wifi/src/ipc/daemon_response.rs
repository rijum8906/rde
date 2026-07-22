//! # Daemon Response Handler Module
//!
//! Processes acknowledgment and response messages received from `rde-daemon`.

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
