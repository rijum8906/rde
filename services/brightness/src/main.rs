use rde_brightness::{brightness::BrightnessController, constants::BACKLIGHT_SYSFS_PATH};
use zbus::connection;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let service = BrightnessController::new(BACKLIGHT_SYSFS_PATH).unwrap();

    // Start D-Bus server (zbus uses tokio internally)
    let _connection = connection::Builder::session()?
        .name("org.rde.Brightness")?
        .serve_at("/org/rde/Brightness", service)?
        .build()
        .await?;

    println!("✅ Brightness service running on org.rde.Brightness");
    println!("Press Ctrl+C to stop");

    tokio::signal::ctrl_c().await?;
    println!("Goodbye!");

    Ok(())
}
