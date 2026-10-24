//! # Main Binary Entry Point
//!
//! Starts the theme service, publishes `org.rde.Theme` on the session bus, and
//! runs until shutdown is requested.

use rde_core::errors::RdeResult;
use rde_theme::app::App;

/// Theme service entry point on a single-threaded Tokio runtime.
///
/// # Errors
/// Returns [`rde_core::errors::RdeError`] if the logger cannot be installed,
/// the session bus is unavailable, the name cannot be claimed, or a signal
/// handler cannot be registered.
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    println!("Starting RDE Theme Service...");

    // Step 1: Initialise logging and the D-Bus object.
    let mut app = App::global()?.lock().await;

    // Step 2: Serve D-Bus and supervision until shutdown is requested.
    app.run().await?;

    println!("RDE Theme Service exited successfully");
    Ok(())
}
