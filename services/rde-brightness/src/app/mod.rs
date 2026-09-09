//! # Application Module
//!
//! Core application lifecycle management and D-Bus service orchestration.
//! Implements the singleton pattern for the Brightness service.
//!
//! ## Architecture
//! The Application manages:
//! - D-Bus connection and interface registration
//! - Daemon supervisor communication via Unix domain sockets
//! - Service lifecycle (startup, shutdown, signal handling)
//! - Graceful error handling and logging
//!
//! ## Design Patterns
//! - **Singleton Pattern**: Global static instance via `OnceLock` for exclusive service access
//! - **Async/Await**: Tokio-based async runtime for I/O operations
//! - **Thread-Safety**: Mutex-protected state for safe concurrent access
//! - **Exponential Backoff**: Socket connection retries with configurable timing
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod handler;

use std::{
    process,
    sync::{Arc, OnceLock},
    time::Instant,
};

use futures_util::lock::Mutex;
use rde_core::{
    errors::{RdeError, RdeResult},
    fs::rde_service_logs_dir,
    logger::{LogLevel, Logger},
    utils::ipc::get_socket_path,
};
use rde_ipc::{
    message::{Message, MessagePayload, RegisterRequest, ServiceRequest},
    socket::IpcClient,
};
use tokio::signal;
use tokio::sync::Mutex as TokioMutex;
use tracing::{debug, error, info, warn};

use crate::{constants::MAX_SOCKET_CONN_RETRY_COUNT, dbus::iface::BrightnessInterface};

/// Main application singleton for the Brightness service.
///
/// Manages the complete service lifecycle including D-Bus registration, daemon
/// communication, signal handling, and graceful shutdown. Thread-safe via mutex wrapping.
///
/// # Fields
/// - `version`: Semantic version from Cargo.toml
/// - `is_running`: Service execution state
/// - `start_time`: Timestamp when service started (for uptime tracking)
/// - `is_conneced`: Connected to daemon supervisor (NOTE: typo preserved for compatibility)
/// - `client`: Async mutex-protected IPC client for daemon communication
/// - `interface`: D-Bus interface handler (consumed after registration)
///
/// # Thread Safety
/// All access to the global singleton is protected by `futures_util::Mutex` to ensure
/// thread-safe state mutations across async task boundaries.
pub struct App {
    /// Service version (e.g., "0.1.0")
    version: String,

    /// Whether service is currently running
    is_running: bool,

    /// Service startup timestamp for uptime calculation
    start_time: Option<Instant>,

    /// Connected to daemon supervisor (typo: `is_conneced` from original codebase)
    is_conneced: bool,

    /// Async-safe IPC client for daemon communication
    /// Wrapped in TokioMutex for background task access
    client: Arc<TokioMutex<Option<IpcClient>>>,

    /// D-Bus interface handler (moved into D-Bus connection, becomes None after run)
    interface: Option<BrightnessInterface>,
}

/// Global singleton application instance
///
/// Use `App::global()` to access. Initialized on first access via `get_or_init`.
/// Panics during initialization if App::new() fails.
static APP_INSTANCE: OnceLock<Mutex<App>> = OnceLock::new();

impl App {
    /// Creates a new `App` instance.
    ///
    /// # Workflow
    /// 1. Initialize structured logger in `~/.local/share/rde/logs/brightness/`
    /// 2. Create D-Bus interface handler (initializes hardware backend)
    /// 3. Set service state to stopped
    ///
    /// # Errors
    /// Returns `RdeError` if:
    /// - Log directory cannot be created
    /// - Logger initialization fails
    /// - Brightness interface creation fails (no backlight hardware)
    fn new() -> RdeResult<Self> {
        // Initialize the global Logger
        debug!("Initializing Logger for Brightness service...");
        let log_dir = rde_service_logs_dir("brightness")?;
        let logger = Logger::new(LogLevel::Info, log_dir, "brightness");
        logger.init()?;

        info!("Creating BrightnessInterface (hardware backend initialization)...");
        // Create a new brightness service
        let brightness_interface = BrightnessInterface::new(logger)?;

        debug!("App instance created successfully");
        Ok(Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            is_running: false,
            start_time: None,
            client: Arc::new(TokioMutex::new(None)),
            interface: Some(brightness_interface),
            is_conneced: false,
        })
    }

    /// Retrieves or creates the global singleton App instance.
    ///
    /// # Behavior
    /// - First call: Initializes via `App::new()` and stores in static `APP_INSTANCE`
    /// - Subsequent calls: Returns reference to already-initialized instance
    ///
    /// # Panics
    /// Panics if `App::new()` fails (e.g., no backlight hardware found).
    /// This is intentional to prevent service startup without hardware capability.
    ///
    /// # Returns
    /// Static reference to the global `App` instance wrapped in Mutex
    pub fn global() -> &'static Mutex<App> {
        APP_INSTANCE.get_or_init(|| {
            let app = App::new().expect("Failed to initialize App - no backlight hardware found");
            Mutex::new(app)
        })
    }

    /// Spawns a background task to establish daemon communication and register service.
    ///
    /// # Workflow
    /// 1. Resolve daemon socket path via `get_socket_path()`
    /// 2. Attempt socket connection with retry logic (MAX_SOCKET_CONN_RETRY_COUNT attempts)
    /// 3. Send `RegisterRequest` with service metadata (PID, name, version, capabilities)
    /// 4. Start supervisor message handling loop to process:
    ///    - HealthCheck requests (liveness monitoring)
    ///    - GetStatus requests (service state reporting)
    ///    - Shutdown requests (graceful termination signal)
    /// 5. On connection loss or error, exit loop and log reason
    ///
    /// # Retry Strategy
    /// - Attempts: 5 (MAX_SOCKET_CONN_RETRY_COUNT)
    /// - Delay: 2000ms between attempts
    /// - Total timeout: ~10 seconds
    /// - Warnings logged for each failed attempt
    /// - Error logged if all attempts exhausted
    ///
    /// # Async Context
    /// Runs in a spawned tokio task separate from main service execution.
    /// Errors during registration do not block service startup.
    ///
    /// # Logging
    /// - WARN: Socket connection retries
    /// - INFO: Successful registration
    /// - ERROR: Fatal failures (socket path resolution, registration failure, connection loss)
    fn start_daemon_monitor(&mut self) {
        let client_clone = Arc::clone(&self.client);
        let version = self.version.clone();
        self.is_conneced = true;

        debug!("Spawning daemon monitor background task...");

        tokio::spawn(async move {
            info!("Daemon monitor: Starting daemon communication task");

            // 1. Resolve socket path
            let socket_path = match get_socket_path() {
                Ok(path) => {
                    debug!("Daemon socket path resolved: {:?}", path);
                    path
                }
                Err(e) => {
                    error!("Failed to get UDS socket path: {}", e);
                    return;
                }
            };

            // 2. Attempt socket connection with retry logic
            let mut connected_client = None;
            for i in 0..MAX_SOCKET_CONN_RETRY_COUNT {
                match IpcClient::connect(&socket_path).await {
                    Ok(c) => {
                        info!(
                            "Successfully connected to daemon socket on attempt {}",
                            i + 1
                        );
                        connected_client = Some(c);
                        break;
                    }
                    Err(e) => {
                        warn!(
                            "Failed to connect to daemon socket (attempt {}/{}): {}",
                            i + 1,
                            MAX_SOCKET_CONN_RETRY_COUNT,
                            e
                        );
                    }
                }
                tokio::time::sleep(std::time::Duration::from_millis(2000)).await;
            }

            if connected_client.is_none() {
                error!(
                    "Could not connect to daemon socket after {} retries",
                    MAX_SOCKET_CONN_RETRY_COUNT
                );
                return;
            }

            let mut client = connected_client.unwrap();

            // 3. Register with daemon
            info!("Sending service registration request to daemon...");
            let message = Message::new(MessagePayload::ServiceRequest(ServiceRequest::Register(
                RegisterRequest {
                    pid: process::id(),
                    name: "brightness".to_string(),
                    version,
                    capabilities: vec![],
                },
            )));

            if let Err(e) = client.send(&message).await {
                error!("Failed to send registration request: {}", e);
                return;
            }

            info!("Service registered with daemon successfully");

            // Save the successfully connected client in the shared mutex
            {
                let mut client_guard = client_clone.lock().await;
                *client_guard = Some(client);
                debug!("IPC client stored in shared state");
            }

            // 4. Process incoming supervisor socket messages
            use crate::app::handler::Handler;
            let mut handler = Handler::new("brightness");
            debug!("Starting supervisor message handling loop...");

            loop {
                // Lock client only to call recv()
                let msg_res = {
                    let mut client_guard = client_clone.lock().await;
                    if let Some(ref mut c) = *client_guard {
                        c.recv().await
                    } else {
                        break;
                    }
                };

                match msg_res {
                    Ok(msg) => {
                        debug!("Received message from supervisor");
                        // Lock client to process the message and send responses
                        let mut client_guard = client_clone.lock().await;
                        if let Some(ref mut c) = *client_guard {
                            let res = handler.handle_message(msg, c).await;
                            if let Err(e) = res {
                                error!("Error handling supervisor message: {}", e);
                                break;
                            }
                        }
                    }
                    Err(e) => {
                        error!("UDS connection to daemon supervisor lost: {}", e);
                        break;
                    }
                }
            }

            warn!("Daemon monitor loop exited - supervisor communication ended");
        });
    }

    /// Runs the Brightness service with D-Bus integration.
    ///
    /// # Workflow
    /// 1. Extract D-Bus interface (consumes `self.interface`)
    /// 2. Create D-Bus session connection and register at `/org/rde/Brightness`
    /// 3. Spawn daemon supervisor communication task in background
    /// 4. Update service state (is_running=true, start_time=now)
    /// 5. Request D-Bus name `org.rde.Brightness`
    /// 6. Wait for Ctrl+C signal
    /// 7. Perform graceful shutdown
    ///
    /// # Errors
    /// Returns `RdeError` if:
    /// - D-Bus interface already taken (run called twice)
    /// - D-Bus connection creation fails
    /// - D-Bus name registration fails
    /// - Signal handling fails
    ///
    /// # Signals
    /// - Ctrl+C (SIGINT): Triggers graceful shutdown sequence
    ///
    /// # Returns
    /// `Ok(())` on clean shutdown, `Err(RdeError)` on fatal error
    pub async fn run(&mut self) -> RdeResult<()> {
        info!("Starting Brightness Application...");

        // Take the brightness interface
        let interface = self.interface.take().ok_or_else(|| {
            error!("BrightnessInterface already taken or run() called multiple times");
            RdeError::Socket("BrightnessInterface has already been taken or run".to_string())
        })?;

        // Build D-Bus connection and register the brightness interface
        info!("Establishing D-Bus session connection...");
        let conn = zbus::connection::Builder::session()?
            .name("org.rde.Brightness")?
            .serve_at("/org/rde/Brightness", interface)?
            .build()
            .await
            .map_err(RdeError::Dbus)?;

        debug!("D-Bus interface registered at /org/rde/Brightness");

        // Spawn connection and supervisor monitoring loop asynchronously in a background task
        info!("Spawning daemon monitor task...");
        self.start_daemon_monitor();

        // Update app states
        self.is_running = true;
        self.start_time = Some(Instant::now());

        // Start the D-Bus service
        info!("Requesting D-Bus name: org.rde.Brightness");
        conn.request_name("org.rde.Brightness").await?;
        info!("Brightness D-Bus service started successfully");

        // Wait for Ctrl+C to exit
        info!("Waiting for Ctrl+C signal to shutdown...");
        signal::ctrl_c().await?;

        info!("Ctrl+C signal received. Shutting down Brightness Application...");
        self.shutdown().await;

        Ok(())
    }

    /// Performs graceful shutdown of the service.
    ///
    /// # Workflow
    /// 1. Close IPC client connection to daemon (if connected)
    /// 2. Clear start time and is_running flags
    /// 3. Log shutdown completion
    ///
    /// # Behavior
    /// - Uses `try_lock()` to avoid blocking on client mutex
    /// - Logs warnings if client close fails (non-fatal)
    /// - Logs info on successful clean shutdown
    ///
    /// # Errors
    /// Does not return errors; all failures logged as warnings
    pub async fn shutdown(&mut self) {
        info!("Performing App cleanup...");

        if self.is_conneced {
            let lock_res = self.client.try_lock();
            if let Ok(mut guard) = lock_res {
                if let Some(mut client) = guard.take() {
                    if let Err(e) = client.close().await {
                        warn!("Failed to close ipc client: {}", e);
                    } else {
                        debug!("IPC client closed successfully");
                    }
                }
                *guard = None;
            } else {
                warn!("Could not acquire lock on IPC client for shutdown");
            }
        }

        self.is_running = false;
        self.start_time = None;
        info!("Brightness service shut down cleanly.");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_brightness_app_lifecycle() {
        let backlight_exists = std::path::Path::new("/sys/class/backlight/")
            .read_dir()
            .map(|mut entries| entries.any(|e| e.is_ok()))
            .unwrap_or(false);
        let app_res = App::new();

        if backlight_exists {
            assert!(
                app_res.is_ok(),
                "Expected App::new to succeed on host with backlight. Error: {:?}",
                app_res.err()
            );
            let mut app = app_res.unwrap();

            assert!(!app.is_running, "App should not be running initially");
            assert!(
                app.start_time.is_none(),
                "Start time should be None initially"
            );

            // Test shutdown state transitions
            app.shutdown().await;
            assert!(!app.is_running, "App should be stopped after shutdown");
            assert!(
                app.start_time.is_none(),
                "Start time should be None after shutdown"
            );
        } else {
            assert!(
                app_res.is_err(),
                "Expected App::new to fail with ConfigNotFound in test/CI environment without backlight"
            );
        }
    }
}
