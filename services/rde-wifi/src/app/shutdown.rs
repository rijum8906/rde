//! # Application Shutdown Handler Module
//!
//! Provides clean resource cleanup and shutdown logic for the `Application` instance.

use rde_core::errors::RdeResult;

use crate::app::Application;

impl Application {
    /// Shuts down the `Application` instance gracefully.
    ///
    /// Notifies the daemon via the `IpcHandler` shutdown sequence, resets IPC connection flags,
    /// marks the service as stopped (`is_running = false`), and clears startup timing metadata.
    ///
    /// # Errors
    /// Returns `RdeError` if sending IPC shutdown messages encounters an unrecoverable failure.
    pub async fn shutdown(&mut self) -> RdeResult<()> {
        if self.is_running {
            if self.is_conneced {
                let mut handler_guard = self.handler.lock().await;
                if let Some(ref mut h) = *handler_guard {
                    if let Err(e) = h.shutdown().await {
                        tracing::error!("Failed to shutdown IPC handler: {}", e);
                    }
                }
                self.is_conneced = false;
            }
            self.is_running = false;
            self.start_time = None;
        }

        Ok(())
    }
}
