//! # Application Lifecycle (`rde-brightness`)
//!
//! Owns the brightness service runtime: the global [`App`] singleton, D-Bus
//! service registration, daemon supervision, and graceful shutdown.
//!
//! ## Features
//! - Poison-safe singleton access through [`App::global`] (no panics on startup)
//! - D-Bus registration of `org.rde.Brightness` at `/org/rde/Brightness`
//! - Supervision task started through [`crate::app::thread`]
//! - Graceful teardown on `SIGINT`, `SIGTERM`, or a supervisor request
//!
//! ## Related
//! - [`crate::app::thread`]: supervision socket task
//! - [`crate::handler`]: daemon message routing
//! - [`crate::dbus::iface::BrightnessInterface`]: served D-Bus object
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

mod thread;

use std::{
    sync::{
        Arc, OnceLock,
        atomic::{AtomicBool, Ordering},
    },
    time::Instant,
};

use futures_util::lock::Mutex;
use rde_core::{
    errors::{RdeError, RdeResult},
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
};
use rde_ipc::{IpcCommand, message::ServiceStatus, thread::IpcThread};
use tokio::signal::unix::{SignalKind, signal};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, warn};

use crate::{
    constants::{DBUS_OBJECT_PATH, DBUS_SERVICE_NAME, SERVICE_NAME, SHUTDOWN_TIMEOUT},
    dbus::iface::BrightnessInterface,
};

/// Global service state, initialised on first use.
static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

/// Process-wide state for the brightness service.
///
/// # Fields
/// - `version`: package version from `CARGO_PKG_VERSION`
/// - `is_running`: whether the event loop is currently serving requests
/// - `start_time`: instant the service started, used for uptime reporting
/// - `connected`: set from the supervision task once the socket is connected
/// - `interface`: D-Bus object handed to the connection during [`App::run`]
/// - `ipc_thread`: handle to the supervision task, owned for clean teardown
/// - `shutdown_token`: cancellation signal any component may trigger
pub struct App {
    /// Package version string (`CARGO_PKG_VERSION`).
    version: String,

    /// Whether the service event loop is running.
    is_running: Arc<AtomicBool>,

    /// Instant at which the service started.
    start_time: Option<Instant>,

    /// Whether the supervision socket is connected to `rde-daemon`.
    connected: Arc<AtomicBool>,

    /// D-Bus object served at [`DBUS_OBJECT_PATH`].
    interface: Option<BrightnessInterface>,

    /// Background supervision task, taken during shutdown.
    ipc_thread: Option<IpcThread>,

    /// Cancellation signal used to break out of the event loop.
    shutdown_token: CancellationToken,
}

impl App {
    /// Builds the application: configures logging and the backlight interface.
    ///
    /// # Workflow
    /// 1. Resolve the service log directory and install the global logger
    /// 2. Create the [`BrightnessInterface`], which opens the backlight backend
    /// 3. Return an idle application state (not running, no supervision task)
    ///
    /// # Errors
    /// Returns [`RdeError`] when the log directory cannot be created, the
    /// logging subscriber cannot be installed, or no usable backlight exists.
    fn new() -> RdeResult<Self> {
        debug!("Initialising logger for the brightness service");

        // Step 1: Install structured logging before touching backlight hardware.
        let log_dir = rde_service_logs_dir(SERVICE_NAME)?;
        let logger = Logger::new(LogLevel::Info, log_dir, SERVICE_NAME);
        logger.init()?;

        // Step 2: Build the interface, which initialises the backlight backend.
        let interface = BrightnessInterface::new(logger)?;

        Ok(Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: Arc::new(AtomicBool::new(false)),
            start_time: None,
            connected: Arc::new(AtomicBool::new(false)),
            interface: Some(interface),
            ipc_thread: None,
            shutdown_token: CancellationToken::new(),
        })
    }

    /// Returns the process-wide application state, creating it on first use.
    ///
    /// # Errors
    /// Returns the initialisation error from [`App::new`] instead of panicking,
    /// so the binary can report a clean failure to the session manager.
    ///
    /// # Returns
    /// A static reference to the mutex-protected application state.
    pub fn global() -> RdeResult<&'static Mutex<App>> {
        if let Some(app) = APP_INSTANCE.get() {
            return Ok(app);
        }

        // Initialise outside the cell: if a concurrent caller wins the race,
        // its instance is the one kept and this one is dropped.
        let app = Self::new()?;
        let _ = APP_INSTANCE.set(Mutex::new(app));

        APP_INSTANCE
            .get()
            .ok_or_else(|| RdeError::Internal("application state failed to initialise".to_string()))
    }

    /// Serves the D-Bus interface and blocks until shutdown is requested.
    ///
    /// # Workflow
    /// 1. Take the D-Bus object (guarding against a second `run` call)
    /// 2. Claim `org.rde.Brightness` and serve the object on the session bus
    /// 3. Spawn the supervision task and mark the service as running
    /// 4. Wait for `SIGINT`, `SIGTERM`, or a supervisor shutdown request
    /// 5. Tear everything down through [`App::shutdown`]
    ///
    /// # Errors
    /// Returns [`RdeError`] when the D-Bus object was already consumed, when
    /// the session bus cannot be reached, or when the name cannot be claimed.
    pub async fn run(&mut self) -> RdeResult<()> {
        info!("Starting brightness service");

        // Step 1: The interface is consumed exactly once.
        let interface = self.interface.take().ok_or_else(|| {
            error!("Brightness interface already consumed, run() must only be called once");
            RdeError::Internal("brightness interface already initialised".to_string())
        })?;

        // Step 2: Publish the object and own the well-known name. `name()`
        // acquires the name as part of `build()`, so no second request is needed.
        let connection = zbus::connection::Builder::session()?
            .name(DBUS_SERVICE_NAME)?
            .serve_at(DBUS_OBJECT_PATH, interface)?
            .build()
            .await?;

        debug!(
            service = DBUS_SERVICE_NAME,
            path = DBUS_OBJECT_PATH,
            pid = std::process::id(),
            "D-Bus interface registered"
        );

        // Step 3: Start daemon supervision and mark the runtime as active.
        self.spawn_daemon_thread();
        self.start();

        info!(
            service = DBUS_SERVICE_NAME,
            version = %self.version,
            "Brightness service is ready"
        );

        // Step 4: Block until a signal or the supervisor asks us to stop.
        tokio::select! {
            _ = self.shutdown_token.cancelled() => {
                info!("Shutdown requested by the daemon supervisor");
            }
            result = wait_for_shutdown_signal() => {
                result?;
                info!("Termination signal received");
            }
        }

        // Step 5: Release the supervision socket and runtime state.
        self.shutdown().await;
        drop(connection);

        info!("Brightness service stopped");
        Ok(())
    }

    /// Requests a graceful shutdown without blocking the caller.
    ///
    /// Used by the supervision handler, which runs inside the supervision task
    /// and therefore must not wait for that task to finish. [`App::run`] picks
    /// up the cancellation and performs the actual teardown.
    pub fn request_shutdown(&self) {
        if self.shutdown_token.is_cancelled() {
            debug!("Shutdown already requested");
            return;
        }

        info!("Graceful shutdown requested");
        self.shutdown_token.cancel();
    }

    /// Stops the supervision task and clears the runtime state.
    ///
    /// # Workflow
    /// 1. Cancel the supervision task and ask it to stop through its channel
    /// 2. Wait for the task to finish, bounded by [`SHUTDOWN_TIMEOUT`]
    /// 3. Reset the running, uptime, and connection flags
    ///
    /// # Note
    /// Must be called from the task that owns the application state
    /// (the binary entry point), never from the supervision task itself.
    pub async fn shutdown(&mut self) {
        // Step 1: Ask the supervision task to stop.
        if let Some(ipc_thread) = self.ipc_thread.take() {
            ipc_thread.cancellation_token.cancel();

            if let Err(error) = ipc_thread.tx.send(IpcCommand::Shutdown).await {
                warn!(%error, "Supervision task already stopped accepting commands");
            }

            // Step 2: Bounded wait so a stuck socket cannot block exit.
            match tokio::time::timeout(SHUTDOWN_TIMEOUT, ipc_thread.handle).await {
                Ok(Ok(())) => debug!("Supervision task stopped"),
                Ok(Err(error)) => warn!(%error, "Supervision task terminated with an error"),
                Err(_) => warn!("Timed out waiting for the supervision task to stop"),
            }
        }

        // Step 3: Clear runtime state so any later status query reports Stopped.
        self.connected.store(false, Ordering::Relaxed);
        self.is_running.store(false, Ordering::Relaxed);
        self.start_time = None;

        info!("Brightness service shut down cleanly");
    }

    /// Returns the package version of the service.
    pub fn version(&self) -> &str {
        &self.version
    }

    /// Returns whether the service event loop is running.
    pub fn is_running(&self) -> bool {
        self.is_running.load(Ordering::Relaxed)
    }

    /// Returns whether the supervision socket is connected.
    pub fn is_connected(&self) -> bool {
        self.connected.load(Ordering::Relaxed)
    }

    /// Returns the execution status reported to the daemon supervisor.
    pub fn status(&self) -> ServiceStatus {
        if self.is_running() {
            ServiceStatus::Running
        } else {
            ServiceStatus::Stopped
        }
    }

    /// Returns the number of whole seconds the service has been running.
    ///
    /// # Returns
    /// `None` while the service is not running.
    pub fn uptime_secs(&self) -> Option<u64> {
        self.start_time.map(|start| start.elapsed().as_secs())
    }

    /// Marks the runtime as started and records the start instant.
    fn start(&mut self) {
        self.is_running.store(true, Ordering::Relaxed);
        self.start_time = Some(Instant::now());
    }
}

/// Waits for `SIGINT` (Ctrl+C) or `SIGTERM` (session exit / `systemctl stop`).
///
/// # Errors
/// Returns [`RdeError::Io`] when the signal handlers cannot be registered.
async fn wait_for_shutdown_signal() -> RdeResult<()> {
    let mut terminate = signal(SignalKind::terminate()).map_err(RdeError::Io)?;

    tokio::select! {
        result = tokio::signal::ctrl_c() => result.map_err(RdeError::Io),
        _ = terminate.recv() => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a state that does not touch logging or backlight hardware.
    fn test_app() -> App {
        App {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: Arc::new(AtomicBool::new(false)),
            start_time: None,
            connected: Arc::new(AtomicBool::new(false)),
            interface: None,
            ipc_thread: None,
            shutdown_token: CancellationToken::new(),
        }
    }

    #[test]
    fn lifecycle_tracks_running_state_and_uptime() {
        let mut app = test_app();
        assert!(!app.is_running());
        assert_eq!(app.status(), ServiceStatus::Stopped);
        assert!(app.uptime_secs().is_none());

        app.start();
        assert!(app.is_running());
        assert_eq!(app.status(), ServiceStatus::Running);
        assert!(app.uptime_secs().is_some());
    }

    #[test]
    fn request_shutdown_is_idempotent() {
        let app = test_app();
        assert!(!app.shutdown_token.is_cancelled());

        app.request_shutdown();
        app.request_shutdown();

        assert!(app.shutdown_token.is_cancelled());
    }

    #[tokio::test]
    async fn shutdown_resets_runtime_state() {
        let mut app = test_app();
        app.connected.store(true, Ordering::Relaxed);
        app.start();

        app.shutdown().await;

        assert!(!app.is_running());
        assert!(!app.is_connected());
        assert!(app.uptime_secs().is_none());
    }

    #[tokio::test]
    async fn run_without_interface_fails_cleanly() {
        let mut app = test_app();

        let error = app.run().await.err();
        assert!(
            matches!(error, Some(RdeError::Internal(_))),
            "a second run must fail with an internal error"
        );
    }

    #[test]
    fn initialisation_follows_hardware_presence() {
        let has_backlight = std::path::Path::new("/sys/class/backlight")
            .read_dir()
            .map(|mut entries| entries.any(|entry| entry.is_ok()))
            .unwrap_or(false);

        let app = App::new();

        if has_backlight {
            assert!(
                app.is_ok(),
                "expected initialisation to succeed with a backlight present: {:?}",
                app.err()
            );
            if let Ok(app) = app {
                assert!(!app.is_running(), "service must start in the stopped state");
                assert_eq!(app.status(), ServiceStatus::Stopped);
            }
        } else {
            assert!(
                app.is_err(),
                "expected initialisation to fail without a backlight"
            );
        }
    }
}
