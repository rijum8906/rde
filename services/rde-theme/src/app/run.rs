//! # Application Startup & Event Execution Loop
//!
//! Handles background IPC task spawning with exponential backoff, D-Bus session bus setup,
//! service name registration (`org.rde.Theme`), and signal monitoring (`Ctrl+C`).
//!
//! ## Features
//! - Spawns background IPC client connecting to `rde-daemon` with retry backoff
//! - Registers public `ThemeInterface` on session D-Bus bus path `/org/rde/Theme`
//! - Acquires `org.rde.Theme` D-Bus service name
//! - Listens for OS signal `Ctrl+C` for graceful termination
//! - Comprehensive startup and shutdown logging
//!
//! ## Related
//! - [`crate::app::Application`]
//! - [`crate::dbus::iface::ThemeInterface`]
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

use crate::{app::Application, dbus::iface::ThemeInterface, ipc::handler::IpcHandler};

impl Application {
    /// Starts the service application event loop.
    ///
    /// # Execution Steps
    /// 1. Spawns background IPC task to connect to `rde-daemon` with exponential backoff retry logic.
    /// 2. Instantiates `ThemeInterface` and registers it on the D-Bus session bus at path `/org/rde/Theme`.
    /// 3. Requests the D-Bus service name `org.rde.Theme`.
    /// 4. Updates application runtime status (running flag, connection state, start time).
    /// 5. Listens for OS signal `Ctrl+C` for graceful shutdown.
    /// 6. Initiates graceful shutdown on signal reception.
    ///
    /// # Logging
    /// - INFO: Major lifecycle events (startup, D-Bus registration, shutdown initiation)
    /// - DEBUG: IPC connector task spawning
    /// - ERROR: Fatal errors during execution
    ///
    /// # Errors
    /// Returns `RdeError` if D-Bus connection or service name acquisition fails.
    pub async fn run(&mut self) -> RdeResult<()> {
        tracing::info!("Theme service starting event loop...");

        // Step 1: Spawn background IPC connector to connect to rde-daemon supervisor
        tracing::debug!("Spawning background IPC connector task with exponential backoff");
        let ipc_handle = self.spawn_ipc_connector().await;

        // Step 2: Initialize D-Bus interface and server object
        tracing::debug!("Initializing D-Bus ThemeInterface");
        let theme_interface = ThemeInterface::new();

        // Step 3: Register org.rde.Theme interface on session D-Bus at path /org/rde/Theme
        tracing::debug!("Connecting to session D-Bus and registering service...");
        let conn = zbus::connection::Builder::session()?
            .name("org.rde.Theme")?
            .serve_at("/org/rde/Theme", theme_interface)?
            .build()
            .await?;

        // Update application runtime status
        self.is_running = true;
        self.is_connected = self.handler.lock().await.is_some();
        self.start_time = Some(std::time::Instant::now());

        // Step 4: Confirm name request on session D-Bus
        tracing::info!(
            "Theme D-Bus service registered successfully on org.rde.Theme (PID: {})",
            std::process::id()
        );
        conn.request_name("org.rde.Theme").await?;

        tracing::info!("Theme service is now running and ready for requests");

        // Step 5: Wait asynchronously for Ctrl+C interruption signal
        match tokio::signal::ctrl_c().await {
            Ok(_) => {
                tracing::warn!("Received Ctrl+C interrupt signal, initiating graceful shutdown...");
            }
            Err(e) => {
                tracing::error!("Signal handler error: {}", e);
            }
        }

        // Step 6: Perform graceful application shutdown
        ipc_handle.abort();
        tracing::debug!("Aborted background IPC connector task");

        if let Err(e) = self.shutdown().await {
            tracing::error!("Shutdown error: {}", e);
        }

        tracing::info!("Theme service shutdown complete");
        Ok(())
    }

    /// Spawns a Tokio background task that attempts connection to `rde-daemon` IPC socket,
    /// retrying up to 5 times with exponential backoff (`2^attempt` seconds delay).
    ///
    /// # Workflow
    /// 1. Attempts IPC connection to daemon socket
    /// 2. On success: Spawns message handler and caches handler reference
    /// 3. On failure: Logs error and waits before retry with exponential backoff
    /// 4. Maximum 5 retry attempts with delays: 1s, 2s, 4s, 8s, 16s
    ///
    /// # Logging
    /// - INFO: Successful connection
    /// - WARN: Failed attempts with attempt counter
    /// - ERROR: Detailed error messages for debugging
    /// - DEBUG: Backoff delay information
    ///
    /// # Returns
    /// Tokio `JoinHandle<()>` for task lifecycle control.
    async fn spawn_ipc_connector(&mut self) -> tokio::task::JoinHandle<()> {
        let max_attempts = 5;
        let ipc_handler = self.handler.clone();

        tokio::spawn(async move {
            for attempt in 0..max_attempts {
                tracing::debug!(
                    "Attempting IPC connection to daemon (attempt {}/{})",
                    attempt + 1,
                    max_attempts
                );

                match IpcHandler::connect().await {
                    Ok(mut h) => {
                        tracing::info!(
                            "Successfully connected to daemon IPC socket (attempt {})",
                            attempt + 1
                        );

                        // Start background IPC message processing loop
                        h.spawn_ipc_message_handler().await;

                        let mut guard = ipc_handler.lock().await;
                        *guard = Some(h);
                        tracing::info!("IPC message handler spawned and connected");
                        return;
                    }
                    Err(e) => {
                        tracing::warn!(
                            "Failed to connect to daemon IPC (attempt {}/{}): {}",
                            attempt + 1,
                            max_attempts,
                            e
                        );
                    }
                }

                // Wait with exponential backoff before next attempt (skip delay on final attempt)
                if attempt < max_attempts - 1 {
                    let delay_secs = 2u64.pow(attempt as u32);
                    let delay = tokio::time::Duration::from_secs(delay_secs);
                    tracing::debug!(
                        "Waiting {}s before retry attempt {} of {}",
                        delay_secs,
                        attempt + 2,
                        max_attempts
                    );
                    tokio::time::sleep(delay).await;
                } else {
                    tracing::error!(
                        "All {} IPC connection attempts failed. Service will continue without daemon supervision.",
                        max_attempts
                    );
                }
            }
        })
    }
}
