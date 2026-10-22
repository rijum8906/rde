//! # Main Binary Entry Point (`rde-volume`)
//!
//! Entry point for the volume service. Initialises the application singleton,
//! publishes `org.rde.Volume` on the session bus, starts the daemon supervision
//! task, and blocks until termination is requested.
//!
//! ## Execution Flow
//! 1. Initialise the application singleton (logger and audio backend)
//! 2. Run the event loop ([`App::run`]): D-Bus registration, supervision, signals
//! 3. Tear down supervision on `SIGINT`, `SIGTERM`, or a supervisor request
//!
//! ## Related
//! - [`rde_volume::app::App`]
//! - [`rde_volume::handler`]
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
use rde_volume::app::App;

/// Volume service entry point on a single-threaded Tokio runtime.
///
/// # Errors
/// Returns [`rde_core::errors::RdeError`] if the logger or audio backend cannot
/// be initialised, the session bus is unavailable, the name cannot be claimed,
/// or a signal handler cannot be registered.
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    println!("Starting RDE Volume Service...");

    // Step 1: Initialise logging and the audio-backed D-Bus object.
    let mut app = App::global()?.lock().await;

    // Step 2: Serve D-Bus and supervision until shutdown is requested.
    app.run().await?;

    println!("RDE Volume Service exited successfully");
    Ok(())
}
