use rde_core::{
    errors::{RdeError, RdeResult},
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};
use rde_daemon::{app::App, ipc::server::Server};

#[tokio::main]
async fn main() -> RdeResult<()> {
    // 1. Initialize the global Logger
    let log_dir = rde_service_logs_dir("daemon")?;
    let logger = Logger::new(LogLevel::Info, log_dir, "daemon");
    logger.init()?;

    tracing::info!("Starting RDE Daemon...");

    // 2. Access the global App state singleton and start it
    // TODO: Read the RDE configuration file from ~/.config/rde/daemon.toml on startup
    // and initialize/spawn the configured services based on the config values.
    let app_mutex = App::global();
    {
        let mut app = app_mutex.lock().unwrap();
        app.start();
    }

    // 3. Start the IPC supervision server
    let server = Server::new()?;

    // 4. Wait for shutdown signal (Ctrl+C)
    tracing::info!("RDE Daemon successfully initialized. Press Ctrl+C to terminate.");
    tokio::signal::ctrl_c().await.map_err(RdeError::Io)?;

    tracing::info!("Received shutdown signal. Stopping RDE Daemon...");

    // 5. Stop the App singleton
    {
        let mut app = app_mutex.lock().unwrap();
        app.stop();
    }

    // 6. Shutdown the IPC supervision server (removes the socket file)
    server.server.shutdown()?;

    tracing::info!("RDE Daemon shut down cleanly.");
    Ok(())
}
