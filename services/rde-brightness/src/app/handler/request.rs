//! # Daemon Request Handler
//!
//! Processes incoming requests from the daemon supervisor.
//! Implements liveness probes, status reporting, and graceful shutdown coordination.
//!
//! ## Request Types
//! - `HealthCheck`: Liveness probe - respond with Alive status
//! - `GetStatus`: Query service state - respond with Running/Stopped status
//! - `Shutdown`: Graceful shutdown request - clean up and exit
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
    message::{DaemonRequest, ServiceResponse, ServiceStatus},
    socket::IpcClient,
};
use tracing::{debug, error, info};

use crate::app::{App, handler::Handler};

impl Handler {
    /// Handles requests pushed by the daemon supervisor.
    ///
    /// Processes three types of requests:
    /// 1. **HealthCheck**: Liveness probe - respond immediately with Alive
    /// 2. **GetStatus**: State query - check app.is_running and respond accordingly
    /// 3. **Shutdown**: Graceful shutdown request - call app.shutdown()
    ///
    /// # Workflow for Each Request Type
    ///
    /// ### HealthCheck
    /// 1. Log DEBUG message receiving check
    /// 2. Send immediate Alive response
    /// 3. Errors logged as warnings (non-fatal)
    ///
    /// ### GetStatus
    /// 1. Lock global app instance
    /// 2. Read is_running state
    /// 3. Send Running or Stopped response based on state
    /// 4. Errors logged as errors (indicates communication failure)
    ///
    /// ### Shutdown
    /// 1. Lock global app instance
    /// 2. Call app.shutdown() (gracefully closes resources)
    /// 3. Log shutdown reason from daemon
    /// 4. No response sent (connection closes after)
    ///
    /// # Errors
    /// Returns `RdeError` if socket send fails (I/O error).
    /// Non-fatal errors (app state checks) are logged but don't propagate.
    ///
    /// # Parameters
    /// - `request`: Daemon request enum variant
    /// - `client`: Mutable IPC client reference for responses
    ///
    /// # Returns
    /// `Ok(())` on successful request handling
    pub async fn handle_daemon_request(
        &mut self,
        request: DaemonRequest,
        client: &mut IpcClient,
    ) -> RdeResult<()> {
        match request {
            DaemonRequest::HealthCheck => {
                debug!("Received HealthCheck request from daemon, sending Alive response");
                match client.send_service_response(ServiceResponse::Alive).await {
                    Ok(_) => debug!("HealthCheck response sent successfully"),
                    Err(e) => error!("Failed to send HealthCheck response: {}", e),
                }
            }
            DaemonRequest::GetStatus(req) => {
                debug!(
                    "Received GetStatus request from daemon for service: {}",
                    req.name
                );
                let is_running = App::global().lock().await.is_running;
                let status = if is_running {
                    debug!("Service status: Running");
                    ServiceStatus::Running
                } else {
                    debug!("Service status: Stopped");
                    ServiceStatus::Stopped
                };
                let status_copy = status.clone();
                match client
                    .send_service_response(ServiceResponse::Status(status))
                    .await
                {
                    Ok(_) => debug!("GetStatus response ({:?}) sent successfully", status_copy),
                    Err(e) => error!("Failed to send GetStatus response: {}", e),
                }
            }
            DaemonRequest::Shutdown {
                service_name,
                reason,
            } => {
                info!(
                    "Daemon supervisor requested shutdown of service {}: {:?}",
                    service_name, reason
                );
                let mut app_guard = App::global().lock().await;
                app_guard.shutdown().await;
                debug!("Service shutdown completed in response to daemon request");
            }
        }
        Ok(())
    }
}
