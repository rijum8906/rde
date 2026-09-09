//! # Main Binary Entry Point (`rde-theme`)
//!
//! Main binary entry point for the `rde-theme` service. Initializes the global
//! application singleton, starts background IPC connection to `rde-daemon`, registers
//! the `org.rde.Theme` session D-Bus interface, and handles runtime event loops.
//!
//! ## Execution Flow
//! 1. Initialize application singleton (logger, version, state)
//! 2. Spawn background IPC connector task (connects to daemon with retry logic)
//! 3. Register D-Bus interface and service name
//! 4. Run event loop (wait for signals and handle requests)
//! 5. Graceful shutdown (cleanup, daemon notification, resource release)
//!
//! ## Features
//! - Application singleton initialization with comprehensive logging
//! - Tokio async runtime execution
//! - Background daemon IPC connector setup with exponential backoff
//! - Session D-Bus service exposure (`org.rde.Theme`)
//! - Signal handling for graceful termination (Ctrl+C)
//! - Structured logging throughout lifecycle
//!
//! ## Related
//! - [`rde_theme::app::Application`](rde_theme::app::Application)
//! - [`rde_theme::dbus::iface::ThemeInterface`](rde_theme::dbus::iface::ThemeInterface)
//! - [`rde_theme::ipc::handler::IpcHandler`](rde_theme::ipc::handler::IpcHandler)
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
use rde_theme::app::Application;

/// Main asynchronous entry point powered by Tokio runtime.
///
/// # Execution
/// 1. Acquires global Application singleton
/// 2. Enters event loop via Application::run()
/// 3. Handles graceful shutdown on Ctrl+C or error
///
/// # Errors
/// Returns `RdeError` if:
/// - Application initialization fails (logger setup, etc.)
/// - D-Bus connection or service registration fails
/// - Runtime execution encounters fatal failure
///
/// # Logging
/// Comprehensive logging is emitted throughout execution:
/// - STDOUT: Service startup confirmation
/// - Log File: All operational events (see `rde_service_logs_dir("theme")`)
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    // Step 1: Acquire exclusive access to the global Application singleton instance
    println!("Starting RDE Theme Service...");
    let mut app = Application::global().await.lock().await;

    // Step 2: Run the service event loop (D-Bus listener + IPC client)
    // This is a blocking operation that runs until Ctrl+C is received
    app.run().await?;

    println!("RDE Theme Service exited successfully");
    Ok(())
}
