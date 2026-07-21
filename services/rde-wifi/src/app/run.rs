use rde_core::errors::RdeResult;

use crate::{app::Application, dbus::iface::WifiInterface, ipc::handler::IpcHandler};

impl Application {
    pub async fn run(&mut self) -> RdeResult<()> {
        // spawn the ipc connector in background
        let ipc_handle = self.spawn_ipc_connector().await;

        let wifi_interface = WifiInterface::new().await?;

        // creae the dbus interface
        let conn = zbus::connection::Builder::session()?
            .name("org.rde.wifi")?
            .serve_at("/org/rde/wifi", wifi_interface)?
            .build()
            .await?;

        // update app metadata
        self.is_conneced = self.handler.lock().await.is_some();
        self.start_time = Some(std::time::Instant::now());

        // Start the dbus service
        tracing::info!("Wifi D-Bus service started successfully on org.rde.wifi");
        conn.request_name("org.rde.wifi").await?;

        // Wait for ctrl + c
        tokio::signal::ctrl_c().await.unwrap();
        tracing::info!("Received Ctrl+C, shutting down...");
        ipc_handle.abort();

        // shutdown
        if let Err(e) = self.shutdown().await {
            tracing::error!("failed to shutdown, {}", e);
        }

        Ok(())
    }

    /// spawn the ipc connector in background
    /// returns the join handle
    async fn spawn_ipc_connector(&mut self) -> tokio::task::JoinHandle<()> {
        let max_attempts = 5;
        let ipc_handler = self.handler.clone();

        // run in background
        tokio::spawn(async move {
            for attempt in 0..max_attempts {
                match IpcHandler::connect().await {
                    Ok(mut h) => {
                        h.spawn_ipc_message_handler().await;

                        let mut guard = ipc_handler.lock().await;
                        *guard = Some(h);
                        tracing::info!("connected to ipc");
                        return;
                    }
                    Err(e) => {
                        // show warning with an attempt number
                        tracing::warn!(
                            "failed to connect to ipc, attempt {}/{}",
                            attempt,
                            max_attempts
                        );
                        // show error details
                        tracing::error!("{}", e);
                    }
                }

                // wait for explonential backoff
                // Don't wait on last attempt
                if attempt < max_attempts {
                    // Exponential backoff
                    let delay = tokio::time::Duration::from_secs(2u64.pow(attempt as u32));
                    tokio::time::sleep(delay).await;
                }
            }
        })
    }
}
