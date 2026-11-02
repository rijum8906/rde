//! # Brightness Service Entry Point
//!
//! Initialises logging, builds the application service, and runs the D-Bus
//! server alongside `rde-daemon` supervision until a shutdown is requested.

use std::sync::Arc;

use rde_brightness::{
    SERVICE_NAME, SERVICE_VERSION,
    application::BrightnessService,
    infrastructure::{dbus, ipc},
};
use rde_core::{
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};
use tokio::signal::unix::{SignalKind, signal};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info};

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    // Step 1: Install structured logging to stdout and the service log file.
    init_tracing()?;
    info!(
        service = SERVICE_NAME,
        version = SERVICE_VERSION,
        "Starting the brightness service"
    );

    // Step 2: Build the application service and start daemon supervision.
    let service = Arc::new(BrightnessService::new());
    let shutdown = CancellationToken::new();
    let supervision = ipc::spawn(shutdown.clone());

    // Step 3: Serve D-Bus until a signal, the supervisor, or an error stops us.
    let result = {
        let serving = dbus::serve(Arc::clone(&service), shutdown.clone());
        tokio::pin!(serving);

        tokio::select! {
            result = &mut serving => result,
            signal = wait_for_shutdown_signal() => {
                signal?;
                info!("Termination signal received, shutting down");
                shutdown.cancel();
                serving.await
            }
        }
    };

    // Step 4: Release the supervision socket and report the outcome.
    ipc::stop(supervision).await;

    if let Err(error) = &result {
        error!(%error, "Brightness service stopped with an error");
    } else {
        info!("Brightness service stopped");
    }

    result
}

/// Installs the shared RDE logger for the brightness service.
///
/// # Errors
/// Returns an error when the log directory cannot be created or the global
/// subscriber is already installed.
fn init_tracing() -> anyhow::Result<()> {
    let is_release_mode = cfg!(not(debug_assertions));
    let log_dir = rde_service_logs_dir(SERVICE_NAME)?;

    // Release builds keep lifecycle events (start, register, shutdown); debug
    // builds add per-operation diagnostics. See `docs/logging-guide.md`.
    let log_level = match is_release_mode {
        true => LogLevel::Info,
        false => LogLevel::Debug,
    };
    Logger::new(log_level, log_dir, SERVICE_NAME).init(is_release_mode)?;
    debug!("Tracing initialised");

    Ok(())
}

/// Waits for `SIGINT` (Ctrl+C) or `SIGTERM` (session exit / `systemctl stop`).
///
/// # Errors
/// Returns an error when the signal handlers cannot be registered.
async fn wait_for_shutdown_signal() -> anyhow::Result<()> {
    let mut terminate = signal(SignalKind::terminate())?;

    tokio::select! {
        result = tokio::signal::ctrl_c() => result.map_err(anyhow::Error::from),
        _ = terminate.recv() => Ok(()),
    }
}
