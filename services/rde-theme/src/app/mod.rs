//! # Application Lifecycle & Singleton Manager
//!
//! Manages global service state, logging subsystem initialization (`rde_core::logger`),
//! versioning, and thread-safe singleton access via `OnceLock`.
//!
//! ## Features
//! - Thread-safe global Application singleton via `OnceLock`
//! - Runtime status tracking (running state, start time, IPC connection state)
//! - Delegated startup and shutdown execution steps
//! - Comprehensive service lifecycle logging
//!
//! ## Related
//! - [`crate::app::run`]
//! - [`crate::app::shutdown`]
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

use std::{
    sync::{Arc, OnceLock},
    time::Instant,
};

use futures_util::lock::Mutex;
use rde_core::errors::RdeResult;

use crate::ipc::handler::IpcHandler;

pub mod run;
pub mod shutdown;

/// The main application singleton managing the `rde-theme` service instance.
///
/// This struct maintains the runtime state of the theme service including:
/// - Service version and identification
/// - Execution state (running/stopped)
/// - IPC connection status
/// - IPC handler reference for daemon communication
pub struct Application {
    /// Package version string (from `CARGO_PKG_VERSION`).
    version: String,

    /// Flag indicating whether the service event loop is running.
    is_running: bool,

    /// Instant timestamp when the service was started.
    start_time: Option<Instant>,

    /// Flag indicating whether the IPC client is actively connected to `rde-daemon`.
    is_connected: bool,

    /// Shared thread-safe handle to the background `IpcHandler`.
    handler: Arc<Mutex<Option<IpcHandler>>>,
}

static APP_INSTANCE: OnceLock<Mutex<Application>> = OnceLock::new();

impl Application {
    /// Creates and initializes a new `Application` instance.
    ///
    /// This method configures the global logger via `rde_core::logger::Logger` writing logs to
    /// the service log directory (`rde_service_logs_dir("theme")`).
    ///
    /// # Workflow
    /// 1. Resolves theme service log directory
    /// 2. Initializes global logger with INFO level
    /// 3. Extracts and stores package version
    /// 4. Returns fully initialized Application singleton
    ///
    /// # Errors
    /// Returns `RdeError` if log directory creation or logger initialization fails.
    pub fn new() -> RdeResult<Self> {
        // Initialize the global RDE logger writing to /var/log/rde or XDG state directory
        let log_dir = rde_core::fs::rde_service_logs_dir("theme")?;
        tracing::info!("Initializing theme service logger in: {:?}", log_dir);

        let logger =
            rde_core::logger::Logger::new(rde_core::logger::LogLevel::Info, log_dir, "theme");
        logger.init()?;

        let version = env!("CARGO_PKG_VERSION").to_string();
        tracing::info!("Theme service v{} initialized", version);

        Ok(Self {
            version,
            is_running: false,
            start_time: None,
            is_connected: false,
            handler: Arc::new(Mutex::new(None)),
        })
    }

    /// Accesses the global `Application` singleton instance safely using `OnceLock`.
    ///
    /// Creates the singleton on first access with proper error handling.
    /// Subsequent accesses return the cached instance.
    ///
    /// # Panics
    /// Panics if logger initialization fails (fatal startup condition).
    pub async fn global() -> &'static Mutex<Self> {
        APP_INSTANCE.get_or_init(|| {
            Mutex::new(Application::new().expect("Failed to initialize Application singleton"))
        })
    }

    /// Returns the Cargo package version string of the service.
    pub fn version(&self) -> &str {
        &self.version
    }

    /// Returns whether the service is currently running.
    pub fn is_running(&self) -> bool {
        self.is_running
    }

    /// Returns the startup `Instant` timestamp if the service has been started.
    pub fn start_time(&self) -> Option<Instant> {
        self.start_time
    }

    /// Returns whether the IPC connection to `rde-daemon` is established.
    pub fn is_connected(&self) -> bool {
        self.is_connected
    }

    /// Returns a reference to the IPC handler for accessing the daemon connection.
    pub fn handler(&self) -> &Arc<Mutex<Option<IpcHandler>>> {
        &self.handler
    }
}
