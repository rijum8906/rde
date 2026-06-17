use rde_theme::dbus::ThemeDBusService;
use zbus::connection;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get the arguments
    let args: Vec<String> = std::env::args().collect();
    let mut storage_name = "theme".to_string();

    // args[0] is the program name, so check args[1] for "test"
    if args.len() > 1 && args[1] == "test" {
        println!("Running in test mode");

        storage_name = "test".to_string();
    }

    let service = ThemeDBusService::new(storage_name)
        .map_err(|e| format!("Failed to create theme service: {}", e))?;

    // Start D-Bus server (zbus uses tokio internally)
    let _connection = connection::Builder::session()?
        .name("org.rde.Theme")?
        .serve_at("/org/rde/Theme", service)?
        .build()
        .await?;

    println!("✅ Theme service running on org.rde.Theme");
    println!("Press Ctrl+C to stop");

    tokio::signal::ctrl_c().await?;
    println!("Theme service stopped");

    Ok(())
}
