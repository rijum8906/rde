//! # Main Binary Entry Point (`rde-brightness`)
//!
//! Entry point for the brightness control service. Initializes the application singleton
//! and runs the main event loop for D-Bus brightness control and daemon supervision.
//!
//! ## Execution Flow
//! 1. Initialize application singleton (logger, backend, D-Bus setup)
//! 2. Spawn background daemon supervisor task
//! 3. Register D-Bus interface and service name
//! 4. Run event loop (handle D-Bus requests and OS signals)
//! 5. Graceful shutdown (cleanup resources, daemon notification)
//!
//! ## Features
//! - Current-thread Tokio runtime (single-threaded, efficient for I/O bound tasks)
//! - Application singleton with thread-safe state management
//! - Comprehensive logging throughout lifecycle
//!
//! ## Related
//! - [`rde_brightness::app::App`](rde_brightness::app::App)
//! - [`rde_brightness::backend::BrightnessBackend`](rde_brightness::backend::BrightnessBackend)
//! - [`rde_brightness::dbus::iface::BrightnessInterface`](rde_brightness::dbus::iface::BrightnessInterface)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_brightness::app::App;
use rde_core::errors::RdeResult;

/// Main entry point powered by single-threaded Tokio runtime.
///
/// # Execution
/// 1. Acquires global App singleton
/// 2. Enters event loop via App::run()
/// 3. Handles graceful shutdown on Ctrl+C or error
///
/// # Errors
/// Returns `RdeError` if:
/// - Application initialization fails (logger setup, backend init, etc.)
/// - D-Bus connection or service registration fails
/// - Runtime execution encounters fatal failure
///
/// # Logging
/// Comprehensive logging is emitted throughout execution at levels:
/// - STDOUT: Service startup confirmation
/// - Log Files: All operational events (in rde_service_logs_dir("brightness"))
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    println!("Starting RDE Brightness Service...");

    // Acquire exclusive access to the global Application singleton instance
    let app = App::global();
    app.lock().await.run().await?;

    println!("RDE Brightness Service exited successfully");
    Ok(())
}
