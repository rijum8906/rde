//! # Service Response Handler
//!
//! Processes [`ServiceResponse`] messages received from supervised services.
//! These are replies to daemon-initiated requests and require no acknowledgement,
//! so handling is limited to structured logging.
//!
//! ## Response Types
//! - `Alive`: liveness confirmation for a health check
//! - `Status`: status snapshot reported by a service
//! - `ShutdownAck`: confirmation that a service accepted a shutdown request
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_ipc::message::ServiceResponse;

/// Records a response sent by a supervised service.
///
/// # Parameters
/// - `response`: the decoded response payload
///
/// # Returns
/// Nothing. Responses are informational and never block the connection.
pub fn handle_client_response(response: ServiceResponse) {
    match response {
        ServiceResponse::Alive => {
            tracing::debug!("Received liveness confirmation from service");
        }
        ServiceResponse::Status(status) => {
            tracing::info!(status = ?status, "Received status response from service");
        }
        ServiceResponse::ShutdownAck(ack) => {
            tracing::info!(
                accepted = ack.success,
                reason = ack.reason.as_deref().unwrap_or_default(),
                "Received shutdown acknowledgement from service"
            );
        }
    }
}
