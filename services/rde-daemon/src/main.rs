//! # Main Binary Entry Point (`rde-daemon`)
//!
//! Entry point for the RDE supervisor daemon. Initialises logging, starts the
//! daemon state, binds the supervision socket, and blocks until the session
//! asks it to terminate.
//!
//! ## Execution Flow
//! 1. Initialise the global logger under `~/.local/rde/logs/daemon/`
//! 2. Start the global [`App`] state and log version/protocol information
//! 3. Bind the supervision socket and start the accept loop
//! 4. Wait for `SIGINT` or `SIGTERM`
//! 5. Stop the daemon state and remove the socket file
//!
//! ## Related
//! - [`rde_daemon::app::App`]: global daemon state
//! - [`rde_daemon::ipc::server::Server`]: supervision socket server
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::{
    errors::{RdeError, RdeResult},
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};
use rde_daemon::{app::App, ipc::server::Server};
use rde_ipc::message::PROTOCOL_VERSION;
use tokio::signal::unix::{SignalKind, signal};

/// Supervisor daemon entry point.
///
/// # Errors
/// Returns an error if the log directory cannot be created, the logger cannot
/// be installed, the supervision socket cannot be bound, or a termination
/// signal handler cannot be registered.
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    // 1. Install structured logging before anything else can fail.
    let log_dir = rde_service_logs_dir("daemon")?;
    Logger::new(LogLevel::Info, log_dir, "daemon").init()?;

    // 2. Start the global daemon state.
    let version = App::with_global(|app| {
        app.start();
        app.version().to_string()
    })?;

    tracing::info!(
        version = %version,
        protocol_version = PROTOCOL_VERSION,
        "RDE Daemon starting"
    );

    // 3. Bind the supervision socket and serve services in the background.
    let server = Server::new()?;
    tracing::info!(
        socket = %server.socket_path().display(),
        "RDE Daemon initialised, waiting for shutdown signal"
    );

    // 4. Block until the session manager or the user asks us to stop.
    wait_for_shutdown_signal().await?;
    tracing::info!("Shutdown signal received");

    // 5. Stop accepting connections and release the socket file, then reset state.
    server.shutdown()?;
    App::with_global(|app| app.stop())?;

    tracing::info!("RDE Daemon shut down cleanly");
    Ok(())
}

/// Waits for `SIGINT` (Ctrl+C) or `SIGTERM` (session exit / `systemctl stop`).
///
/// # Errors
/// Returns an error if the signal handlers cannot be registered.
async fn wait_for_shutdown_signal() -> RdeResult<()> {
    let mut terminate = signal(SignalKind::terminate()).map_err(RdeError::Io)?;

    tokio::select! {
        result = tokio::signal::ctrl_c() => result.map_err(RdeError::Io),
        _ = terminate.recv() => Ok(()),
    }
}
