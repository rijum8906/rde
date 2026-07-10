use rde_brightness::dbus::iface::BrightnessInterface;
use rde_core::errors::{RdeError, RdeResult};
use tokio::signal;
use zbus::connection;

#[tokio::main]
async fn main() -> RdeResult<()> {
    // create a new brightness service
    let brightness_interface = BrightnessInterface::new()?;

    // build dbus connection and register the brightness interface
    let conn = connection::Builder::session()?
        .name("org.rde.Brightness")?
        .serve_at("/org/rde/Brightness", brightness_interface)?
        .build()
        .await
        .map_err(RdeError::Dbus)?;

    println!("Brightness service started on org.rde.Brightness");
    conn.request_name("org.rde.Brightness").await?;

    // Wait for Ctrl+C to exit
    signal::ctrl_c().await?;

    Ok(())
}
