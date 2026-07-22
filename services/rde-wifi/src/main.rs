//! Main binary entry point for the `rde-wifi` service.
//!
//! This binary initializes the global singleton `Application` instance, starts the
//! background IPC link with `rde-daemon`, registers the `org.rde.wifi` session D-Bus interface,
//! and runs until a termination signal (`Ctrl+C` or daemon request) is received.

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
