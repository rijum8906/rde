//! # Application Startup & Event Execution Loop (`rde-volume`)
//!
//! Handles background IPC task spawning with exponential backoff, D-Bus session bus setup,
//! service name registration (`org.rde.Volume`), and signal monitoring (`Ctrl+C`).
//!
//! ## Features
//! - Spawns background IPC client connecting to `rde-daemon` with retry backoff
//! - Registers public `VolumeInterface` on session D-Bus bus path `/org/rde/Volume`
//! - Acquires `org.rde.Volume` D-Bus service name
//! - Listens for OS signal `Ctrl+C` for graceful termination
//!
//! ## Related
//! - [`crate::app::Application`]
//! - [`crate::dbus::iface::VolumeInterface`]
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

use rde_core::errors::{RdeError, RdeResult};

use crate::{
    app::Application,
    dbus::iface::VolumeInterface,
    domain::models::{DBUS_OBJECT_PATH, DBUS_SERVICE_NAME},
    ipc::handler::IpcHandler,
};

impl Application {
    /// Starts the service application event loop.
    ///
    /// # Execution Steps
    /// 1. Spawns background IPC task to connect to `rde-daemon` with exponential backoff retry logic.
    /// 2. Instantiates `VolumeInterface` and registers it on the D-Bus session bus at path `/org/rde/Volume`.
    /// 3. Requests the D-Bus service name `org.rde.Volume`.
    /// 4. Listens for OS signal `Ctrl+C` for graceful shutdown.
    ///
    /// # Errors
    /// Returns `RdeError` if D-Bus connection or service name acquisition fails.
    pub async fn run(&mut self) -> RdeResult<()> {
        // Step 1: Spawn background IPC connector to connect to rde-daemon supervisor
        let ipc_handle = self.spawn_ipc_connector().await;

        // Step 2: Initialize D-Bus interface and server object
        let volume_interface = VolumeInterface::new().await?;

        // Step 3: Register org.rde.Volume interface on session D-Bus at path /org/rde/Volume
        let conn = zbus::connection::Builder::session()?
            .name(DBUS_SERVICE_NAME)?
            .serve_at(DBUS_OBJECT_PATH, volume_interface)?
            .build()
            .await?;

        // Update application runtime status
        self.is_running = true;
        self.is_connected = self.handler.lock().await.is_some();
        self.start_time = Some(std::time::Instant::now());

        // Step 4: Confirm name request on session D-Bus
        tracing::info!(
            "Volume D-Bus service started successfully on {}",
            DBUS_SERVICE_NAME
        );
        let _ = conn.request_name(DBUS_SERVICE_NAME).await;

        // Step 5: Wait asynchronously for Ctrl+C interruption signal
        tokio::signal::ctrl_c().await.map_err(RdeError::Io)?;
        tracing::info!("Received Ctrl+C, shutting down...");
        ipc_handle.abort();

        // Step 6: Perform graceful application shutdown
        if let Err(e) = self.shutdown().await {
            tracing::error!("Failed to shutdown volume service cleanly: {}", e);
        }

        Ok(())
    }

    /// Spawns a Tokio background task that attempts connection to `rde-daemon` IPC socket,
    /// retrying up to 5 times with exponential backoff (`2^attempt` seconds delay).
    ///
    /// # Returns
    /// Tokio `JoinHandle<()>` for task lifecycle control.
    async fn spawn_ipc_connector(&mut self) -> tokio::task::JoinHandle<()> {
        let max_attempts = 5;
        let ipc_handler = self.handler.clone();

        tokio::spawn(async move {
            for attempt in 0..max_attempts {
                match IpcHandler::connect().await {
                    Ok(mut h) => {
                        // Start background IPC message processing loop
                        h.spawn_ipc_message_handler().await;

                        let mut guard = ipc_handler.lock().await;
                        *guard = Some(h);
                        tracing::info!("Connected to rde-daemon IPC socket");
                        return;
                    }
                    Err(e) => {
                        tracing::warn!(
                            "Failed to connect to IPC daemon, attempt {}/{}: {}",
                            attempt + 1,
                            max_attempts,
                            e
                        );
                    }
                }

                // Wait with exponential backoff before next attempt (skip delay on final attempt)
                if attempt < max_attempts - 1 {
                    let delay = tokio::time::Duration::from_secs(2u64.pow(attempt as u32));
                    tokio::time::sleep(delay).await;
                }
            }
        })
    }
}
