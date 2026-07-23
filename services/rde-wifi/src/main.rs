//! # Main Binary Entry Point (`rde-wifi`)
//!
//! Main binary entry point for the `rde-wifi` service. Initializes the global
//! application singleton, starts background IPC connection to `rde-daemon`, registers
//! the `org.rde.wifi` session D-Bus interface, and handles runtime event loops.
//!
//! ## Features
//! - Application singleton initialization
//! - Tokio async runtime execution
//! - Background daemon IPC connector setup
//! - Session D-Bus service exposure (`org.rde.wifi`)
//!
//! ## Related
//! - [`rde_wifi::app::Application`](crate::app::Application)
//! - [`rde_wifi::dbus::iface::WifiInterface`](crate::dbus::iface::WifiInterface)
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
use rde_wifi::app::Application;

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
