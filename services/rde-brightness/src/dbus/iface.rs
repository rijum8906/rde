use crate::backend::BrightnessBackend;
use rde_core::{
    errors::RdeResult,
    logger::{LogLevel, Logger},
    utils::logger::init_log_dir,
};
use zbus::interface;

/// Brightness D-Bus interface
pub struct BrightnessInterface {
    pub backend: BrightnessBackend,
    pub logger: Logger,
}

impl BrightnessInterface {
    pub fn new() -> RdeResult<Self> {
        // create a logger
        let base_log_dir = init_log_dir()?;
        let log_dir = base_log_dir.join("brightness");

        let logger = Logger::new(LogLevel::Info, log_dir, "brightness".to_string());

        // crate an instance of the backend
        let mut backend = BrightnessBackend::new()?;

        // initialize the backend
        backend.init()?;

        Ok(Self { backend, logger })
    }
}

#[interface(name = "org.rde.Brightness")]
impl BrightnessInterface {
    // ========= PROPERTIES ==========
    /// Returns the version of the service
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        // get the version from Cargo.toml
        let version = env!("CARGO_PKG_VERSION");

        Ok(version.to_string())
    }

    // get raw brightness value
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness(&self) -> zbus::fdo::Result<u32> {
        self.backend
            .get_brightness()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    // set raw brightness value
    #[zbus(property)]
    pub async fn set_brightness(
        &mut self,
        brightness: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        self.backend
            .set_brightness(brightness)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Calculate current percent to emit signal with percentage
        let percent = self
            .backend
            .get_brightness_percent()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Emit custom BrightnessChanged signal
        Self::emit_brightness_changed(&emitter, percent)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(())
    }

    // get brightness percentage (0-100)
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness_percent(&self) -> zbus::fdo::Result<u32> {
        self.backend
            .get_brightness_percent()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    // set brightness percentage (0-100)
    #[zbus(property)]
    pub async fn set_brightness_percent(
        &mut self,
        percent: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let max = self.backend.max_brightness;
        let raw_val = (percent * max) / 100;

        self.backend
            .set_brightness(raw_val)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Emit custom BrightnessChanged signal
        Self::emit_brightness_changed(&emitter, percent)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(())
    }

    // get max brightness value
    #[zbus(property)]
    pub fn max_brightness(&self) -> zbus::fdo::Result<u32> {
        self.backend
            .get_max_brightness()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    // ========= METHODS ==========
    #[zbus(name = "SetBrightness")]
    pub async fn set_brightness_method(
        &mut self,
        percent: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let max = self.backend.max_brightness;
        let raw_val = (percent * max) / 100;

        self.backend
            .set_brightness(raw_val)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Self::emit_brightness_changed(&emitter, percent)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(())
    }

    #[zbus(name = "GetBrightness")]
    pub fn get_brightness_method(&self) -> zbus::fdo::Result<u32> {
        self.backend
            .get_brightness_percent()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    #[zbus(name = "IncreaseBrightness")]
    pub async fn increase_brightness(
        &mut self,
        step: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        let current_percent = self
            .backend
            .get_brightness_percent()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        let new_percent = std::cmp::min(current_percent + step, 100);

        let max = self.backend.max_brightness;
        let raw_val = (new_percent * max) / 100;

        self.backend
            .set_brightness(raw_val)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Self::emit_brightness_changed(&emitter, new_percent)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(new_percent)
    }

    #[zbus(name = "DecreaseBrightness")]
    pub async fn decrease_brightness(
        &mut self,
        step: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        let current_percent = self
            .backend
            .get_brightness_percent()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        let new_percent = current_percent.saturating_sub(step);

        let max = self.backend.max_brightness;
        let raw_val = (new_percent * max) / 100;

        self.backend
            .set_brightness(raw_val)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Self::emit_brightness_changed(&emitter, new_percent)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(new_percent)
    }

    // ========= SIGNALS ==========
    #[zbus(signal, name = "BrightnessChanged")]
    pub async fn emit_brightness_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        percent: u32,
    ) -> zbus::Result<()>;
}
