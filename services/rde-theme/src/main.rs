//! # Main Binary Entry Point (`rde-theme`)
//!
//! Starts the theme service, publishes `org.rde.Theme` on the session bus, and
//! runs until shutdown is requested.

use rde_core::errors::RdeResult;
use rde_theme::app::App;

/// Main entry point on Tokio runtime.
///
/// # Errors
/// Returns [`rde_core::errors::RdeError`] if initialization, D-Bus registration,
/// or signal handling fails.
#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    let mut app = App::new().await?;
    app.run().await
}
