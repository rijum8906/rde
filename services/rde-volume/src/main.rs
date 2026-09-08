//! # Main Binary Entry Point (`rde-volume`)
//!
//! Main binary entry point for the `rde-volume` service. Initializes the global
//! application singleton, starts background IPC connection to `rde-daemon`, registers
//! the `org.rde.Volume` session D-Bus interface, and handles runtime event loops.
//!
//! ## Features
//! - Application singleton initialization
//! - Tokio async runtime execution
//! - Background daemon IPC connector setup
//! - Session D-Bus service exposure (`org.rde.Volume`)
//!
//! ## Related
//! - [`rde_volume::app::Application`](crate::app::Application)
//! - [`rde_volume::dbus::iface::VolumeInterface`](crate::dbus::iface::VolumeInterface)
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
use rde_volume::app::Application;

/// Main asynchronous entry point powered by Tokio runtime.
///
/// # Errors
/// Returns `RdeError` if initialization, logging setup, D-Bus service registration,
/// or runtime execution encounters a fatal failure.
#[tokio::main]
async fn main() -> RdeResult<()> {
    // Acquire exclusive access to the global Application singleton instance
    let mut app = Application::global().await.lock().await;

    // Run the service event loop (D-Bus listener + IPC client)
    app.run().await?;

    Ok(())
}
