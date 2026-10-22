//! # Supervisor Response Handler (`rde-theme`)
//!
//! Processes acknowledgements sent back by the `rde-daemon` supervisor.
//!
//! ## Response Types
//! - `RegisterAck`: registration outcome, including a rejection reason
//!
//! ## Related
//! - [`crate::handler::handle_message`][]: caller
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

use crate::constants::SERVICE_NAME;

/// Handles a response from the supervisor.
///
/// # Parameters
/// - `response`: decoded response payload
/// - `_client`: unused connection, kept for symmetry with the request handler
///
/// # Errors
/// Never fails: responses are informational and only affect logging.
pub async fn handle_daemon_response(
    response: DaemonResponse,
    _client: &mut IpcClient,
) -> RdeResult<()> {
    match response {
        DaemonResponse::RegisterAck(ack) => {
            if ack.success {
                info!(
                    service = SERVICE_NAME,
                    pid = std::process::id(),
                    "Supervisor acknowledged the registration"
                );
            } else {
                error!(
                    service = SERVICE_NAME,
                    reason = ack.reason.as_deref().unwrap_or("unspecified"),
                    "Supervisor rejected the registration"
                );
            }
        }
    }

    Ok(())
}
