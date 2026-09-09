//! # Application Shutdown Handler Module
//!
//! Provides clean resource cleanup and shutdown logic for the `Application` instance.
//!
//! ## Features
//! - Sends graceful shutdown signal to daemon supervisor via IPC
//! - Resets IPC connection state and runtime flags
//! - Clears startup timestamps and active loop states
//! - Comprehensive shutdown logging
//!
//! ## Related
//! - [`crate::app::Application`]
//! - [`crate::ipc::handler::IpcHandler`]
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

use crate::app::Application;

impl Application {
    /// Shuts down the `Application` instance gracefully.
    ///
    /// # Workflow
    /// 1. Checks if service is running
    /// 2. Notifies daemon via IPC shutdown sequence if connected
    /// 3. Resets IPC connection flags and handler reference
    /// 4. Marks service as stopped
    /// 5. Clears startup timing metadata
    ///
    /// # Logging
    /// - INFO: Shutdown initiation and completion
    /// - WARN: When not running (redundant shutdown)
    /// - ERROR: IPC handler shutdown failures (logged but not fatal)
    /// - DEBUG: Detailed shutdown steps
    ///
    /// # Errors
    /// Returns `RdeError` if sending IPC shutdown messages encounters an unrecoverable failure.
    ///
    /// Note: IPC handler errors are logged but do not propagate, allowing graceful shutdown
    /// even if daemon communication fails.
    pub async fn shutdown(&mut self) -> RdeResult<()> {
        if self.is_running {
            tracing::info!("Initiating application shutdown sequence");

            if self.is_connected {
                tracing::debug!("Notifying daemon of theme service shutdown");
                let mut handler_guard = self.handler.lock().await;
                if let Some(ref mut h) = *handler_guard {
                    if let Err(e) = h.shutdown().await {
                        tracing::error!("Failed to shutdown IPC handler gracefully: {}", e);
                        // Continue shutdown even if IPC handler fails
                    }
                }
                self.is_connected = false;
                tracing::debug!("IPC handler shutdown complete");
            }

            self.is_running = false;
            self.start_time = None;
            tracing::info!("Application shutdown sequence completed successfully");
        } else {
            tracing::warn!("Shutdown requested but application is not running");
        }

        Ok(())
    }
}
