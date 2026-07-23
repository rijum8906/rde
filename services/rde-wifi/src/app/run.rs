//! # Application Startup & Event Execution Loop
//!
//! Handles background IPC task spawning with exponential backoff, D-Bus session bus setup,
//! service name registration (`org.rde.wifi`), and signal monitoring (`Ctrl+C`).
//!
//! ## Features
//! - Spawns background IPC client connecting to `rde-daemon` with retry backoff
//! - Registers public `WifiInterface` on session D-Bus bus path `/org/rde/wifi`
//! - Acquires `org.rde.wifi` D-Bus service name
//! - Listens for OS signal `Ctrl+C` for graceful termination
//!
//! ## Related
//! - [`crate::app::Application`]
//! - [`crate::dbus::iface::WifiInterface`]
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

use crate::{app::Application, dbus::iface::WifiInterface, ipc::handler::IpcHandler};

impl Application {
    /// Starts the service application event loop.
    ///
    /// # Execution Steps
    /// 1. Spawns background IPC task to connect to `rde-daemon` with exponential backoff retry logic.
    /// 2. Instantiates `WifiInterface` and registers it on the D-Bus session bus at path `/org/rde/wifi`.
    /// 3. Requests the D-Bus service name `org.rde.wifi`.
    /// 4. Listens for OS signal `Ctrl+C` for graceful shutdown.
    ///
    /// # Errors
    /// Returns `RdeError` if D-Bus connection or service name acquisition fails.
    pub async fn run(&mut self) -> RdeResult<()> {
        // Step 1: Spawn background IPC connector to connect to rde-daemon supervisor
        let ipc_handle = self.spawn_ipc_connector().await;

        // Step 2: Initialize D-Bus interface and server object
        let wifi_interface = WifiInterface::new().await?;

        // Step 3: Register org.rde.wifi interface on session D-Bus at path /org/rde/wifi
        let conn = zbus::connection::Builder::session()?
            .name("org.rde.wifi")?
            .serve_at("/org/rde/wifi", wifi_interface)?
            .build()
            .await?;

        // Update application runtime status
        self.is_running = true;
        self.is_conneced = self.handler.lock().await.is_some();
        self.start_time = Some(std::time::Instant::now());

        // Step 4: Confirm name request on session D-Bus
        tracing::info!("Wifi D-Bus service started successfully on org.rde.wifi");
        conn.request_name("org.rde.wifi").await?;

        // Step 5: Wait asynchronously for Ctrl+C interruption signal
        tokio::signal::ctrl_c().await.unwrap();
        tracing::info!("Received Ctrl+C, shutting down...");
        ipc_handle.abort();

        // Step 6: Perform graceful application shutdown
        if let Err(e) = self.shutdown().await {
            tracing::error!("failed to shutdown, {}", e);
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
                        tracing::info!("connected to ipc");
                        return;
                    }
                    Err(e) => {
                        tracing::warn!(
                            "failed to connect to ipc, attempt {}/{}",
                            attempt + 1,
                            max_attempts
                        );
                        tracing::error!("{}", e);
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
