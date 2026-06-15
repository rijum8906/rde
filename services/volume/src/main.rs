use std::fmt::format;

use rde_volume::volume::VolumeController;
use zbus::connection;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let service = VolumeController::new()
        .map_err(|e| format!("Failed to create volume controller: {}", e))?;

    // Start D-Bus server (zbus uses tokio internally)
    let _connection = connection::Builder::session()?
        .name("org.rde.Volume")?
        .serve_at("/org/rde/Volume", service)?
        .build()
        .await?;

    println!("✅ Volume service running on org.rde.Volume");
    println!("Press Ctrl+C to stop");

    tokio::signal::ctrl_c().await?;
    println!("Volume service stopped");

    Ok(())
}
