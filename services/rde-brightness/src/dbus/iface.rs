use rde_core::errors::RdeResult;
use zbus::{
    fdo::{Error, Result},
    interface, proxy,
};

use crate::backend::BrightnessBackend;

/// Brightness D-Bus interface
pub struct BrightnessInterface {
    pub backend: BrightnessBackend,
}

impl BrightnessInterface {
    pub fn new() -> RdeResult<Self> {
        // crate an instance of the backend
        let mut backend = BrightnessBackend::new()?;

        // initialize the backend
        backend.init()?;

        Ok(Self { backend })
    }
}

#[interface(name = "org.rde.Brightness")]
impl BrightnessInterface {
    // ========= PROPERTIES ==========
    /// Returns the version of the service
    #[zbus(property)]
    pub fn version(&self) -> Result<String> {
        // get the version from Cargo.toml
        let version = env!("CARGO_PKG_VERSION");

        Ok(version.to_string())
    }

    // get brightness %tage
    #[zbus(property)]
    pub fn brightness(&self) -> Result<u32> {
        self.backend
            .get_brightness()
            .map_err(|e| Error::Failed(e.to_string()))
    }

    // set brightness %tage
    #[zbus(property)]
    pub async fn set_brightness(
        &mut self,
        brightness: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> Result<()> {
        self.backend
            .set_brightness(brightness)
            .map_err(|e| Error::Failed(e.to_string()))?;

        // Emit custom BrightnessChanged signal
        Self::emit_brightness_changed(&emitter, brightness)
            .await
            .map_err(|e| Error::Failed(e.to_string()))?;

        Ok(())
    }

    // get max brightness value
    #[zbus(property)]
    pub fn max_brightness(&self) -> Result<u32> {
        self.backend
            .get_max_brightness()
            .map_err(|e| Error::Failed(e.to_string()))
    }

    // ========= SIGNALS ==========
    #[zbus(signal)]
    #[zbus(name = "BrightnessChanged")]
    pub async fn emit_brightness_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        percent: u32,
    ) -> zbus::Result<()>;
}

#[proxy(
    default_service = "org.rde.Brightness",
    default_path = "/org/rde/Brightness",
    interface = "org.rde.Brightness"
)]
trait BrightnessManager {
    #[zbus(property)]
    fn brightness(&self) -> zbus::Result<u32>;

    #[zbus(property)]
    fn set_brightness(&self, brightness: u32) -> zbus::Result<()>;

    #[zbus(signal)]
    #[zbus(name = "BrightnessChanged")]
    fn brightness_changed_signal(&self, percent: u32) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures_util::StreamExt;
    use zbus::Connection;

    #[tokio::test]
    async fn test_property_changed_signal() {
        // create the service
        let brightness_interface = BrightnessInterface::new().unwrap();
        let conn = Connection::session().await.unwrap();

        // Register the service
        conn.object_server()
            .at("/org/rde/Brightness", brightness_interface)
            .await
            .unwrap();

        // Request the bus name
        conn.request_name("org.rde.Brightness").await.unwrap();

        // Create the proxy
        let brightness_manager_proxy = BrightnessManagerProxy::new(&conn).await.unwrap();

        // Listen for the custom BrightnessChanged signal
        let mut signal_stream = brightness_manager_proxy
            .receive_brightness_changed_signal()
            .await
            .unwrap();

        // Set brightness to a new value via the proxy
        brightness_manager_proxy.set_brightness(75).await.unwrap();

        // Await the signal from the stream
        if let Some(signal) = signal_stream.next().await {
            let args = signal.args().unwrap();
            assert_eq!(args.percent, 75);
        } else {
            panic!("Did not receive BrightnessChanged signal");
        }
    }
}
