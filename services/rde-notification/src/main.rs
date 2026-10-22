//! # Main Binary Entry Point (`rde-notification`)
//!
//! Entry point for the notification service. Initialises the application
//! singleton, starts the daemon supervision task, and blocks until termination
//! is requested.
//!
//! ## Execution Flow
//! 1. Initialise the application singleton (logger and runtime state)
//! 2. Run the event loop ([`App::run`]): supervision, signals
//! 3. Tear down supervision on `SIGINT`, `SIGTERM`, or a supervisor request
//!
//! ## Related
//! - [`rde_notification::app::App`]
//! - [`rde_notification::handler`]
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
use rde_notification::app::App;

/// Notification service entry point on a single-threaded Tokio runtime.
///
/// # Errors
/// Returns [`rde_core::errors::RdeError`] if the logger cannot be installed or
/// a signal handler cannot be registered.
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    println!("Starting RDE Notification Service...");

    // Step 1: Initialise logging and the runtime state.
    let mut app = App::global()?.lock().await;

    // Step 2: Serve supervision until shutdown is requested.
    app.run().await?;

    println!("RDE Notification Service exited successfully");
    Ok(())
}
