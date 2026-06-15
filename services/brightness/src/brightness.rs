use std::{fs, path::{Path, PathBuf}, process::Command, sync::Arc};

use zbus::{
    fdo::{Error, Result},
    interface,
    object_server::SignalEmitter,
};

use crate::constants::{BRIGHTNESS_FILE, BRIGHTNESS_HELPER_COMMAND, MAX_BRIGHTNESS_FILE};

pub trait Brightness {
    fn get_brightness(&self) -> Result<u16>;
    fn get_brightness_percentage(&self) -> Result<u8>;
    fn set_brightness(&self, value: u16) -> Result<()>;
    fn set_brightness_percentage(&self, value: u8) -> Result<()>;
    fn increase_brightness(&self, value: u16) -> Result<()>;
    fn decrease_brightness(&self, value: u16) -> Result<()>;
    fn increase_brightness_percentage(&self, value: u8) -> Result<()>;
    fn decrease_brightness_percentage(&self, value: u8) -> Result<()>;
    fn get_max_brightness(&self) -> Result<u16>;
}

pub trait Executor: Send + Sync {
    fn execute(&self, path: &Path, value: u16) -> Result<()>;
}

pub struct PkexecExecutor;

impl Executor for PkexecExecutor {
    fn execute(&self, path: &Path, value: u16) -> Result<()> {
        let status = Command::new("pkexec")
            .arg(BRIGHTNESS_HELPER_COMMAND)
            .arg(path)
            .arg(value.to_string())
            .status()
            .map_err(|e| Error::Failed(e.to_string()))?;
        if status.success() {
            Ok(())
        } else {
            Err(zbus::fdo::Error::Failed(
                "Failed to set brightness".to_string(),
            ))
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum BacklightType {
    Intel,
    Amd,
    Nvidia,
    Acpi,
    Generic,
}

// Implementation
pub struct BrightnessController {
    backlight_path: PathBuf,
    max_brightness: u16,
    executor: Arc<dyn Executor>,
}

impl BrightnessController {
    pub fn new(path: &str) -> Result<Self> {
        Self::with_executor(path, Arc::new(PkexecExecutor))
    }

    pub fn with_executor(path: &str, executor: Arc<dyn Executor>) -> Result<Self> {
        // Find backlight device
        let backlight_dir = PathBuf::from(path);
        let devices = match fs::read_dir(&backlight_dir) {
            Ok(d) => d,
            Err(e) => return Err(zbus::fdo::Error::Failed(e.to_string())),
        };

        // Read the first device
        let mut first_device = devices.filter_map(|s| s.ok());
        let dir_entry = match first_device.next() {
            Some(p) => p,
            None => {
                return Err(zbus::fdo::Error::Failed(
                    "No backlight device found".to_string(),
                ));
            }
        };
        let device_path = dir_entry.path();

        // Read max brightness
        let max_brightness_path = device_path.join(MAX_BRIGHTNESS_FILE);
        let max_str = match fs::read_to_string(&max_brightness_path) {
            Ok(s) => s,
            Err(e) => return Err(zbus::fdo::Error::Failed(e.to_string())),
        };
        // Parse
        let max_brightness = match max_str.trim().parse() {
            Ok(u) => u,
            Err(_) => {
                return Err(zbus::fdo::Error::Failed(
                    "Unsupported brightness value".to_string(),
                ));
            }
        };

        Ok(Self {
            backlight_path: device_path,
            max_brightness,
            executor,
        })
    }
}

impl Brightness for BrightnessController {
    fn get_brightness(&self) -> Result<u16> {
        let value_path = self.backlight_path.join(BRIGHTNESS_FILE);
        let value_str = match fs::read_to_string(&value_path) {
            Ok(s) => s,
            Err(e) => {
                return Err(zbus::fdo::Error::Failed(e.to_string()));
            }
        };

        // Parse and return
        match value_str.trim().parse() {
            Ok(u) => Ok(u),
            Err(_) => Err(zbus::fdo::Error::Failed(
                "Unsupported brightness value".to_string(),
            )),
        }
    }

    fn get_brightness_percentage(&self) -> Result<u8> {
        let value = self.get_brightness()?;
        Ok((value as f64 / self.max_brightness as f64 * 100.0).round() as u8)
    }

    fn set_brightness(&self, value: u16) -> Result<()> {
        // Check if value is in range
        if value > self.max_brightness {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Unsupported brightness value".to_string(),
            ));
        }
        let value_path = self.backlight_path.join(BRIGHTNESS_FILE);
        self.executor.execute(&value_path, value)
    }

    fn set_brightness_percentage(&self, value: u8) -> Result<()> {
        if value > 100 {
            return Err(zbus::fdo::Error::InvalidArgs(
                "Unsupported brightness value".to_string(),
            ));
        }
        self.set_brightness((value as f64 / 100.0 * self.max_brightness as f64).round() as u16)
    }

    fn increase_brightness(&self, value: u16) -> Result<()> {
        let current_brightness = self.get_brightness()?;
        let new_brightness = current_brightness
            .saturating_add(value)
            .min(self.max_brightness);
        self.set_brightness(new_brightness)
    }

    fn decrease_brightness(&self, value: u16) -> Result<()> {
        let current_brightness = self.get_brightness()?;
        let new_brightness = current_brightness.saturating_sub(value);
        self.set_brightness(new_brightness)
    }

    fn increase_brightness_percentage(&self, value: u8) -> Result<()> {
        let current_percentage = self.get_brightness_percentage()?;
        let new_percentage = current_percentage.saturating_add(value).min(100);
        self.set_brightness_percentage(new_percentage)
    }

    fn decrease_brightness_percentage(&self, value: u8) -> Result<()> {
        let current_percentage = self.get_brightness_percentage()?;
        let new_percentage = current_percentage.saturating_sub(value);
        self.set_brightness_percentage(new_percentage)
    }

    fn get_max_brightness(&self) -> Result<u16> {
        Ok(self.max_brightness)
    }
}

#[interface(name = "org.rde.Brightness")]
impl BrightnessController {
    // Properties
    #[zbus(property, name = "Brightness")]
    pub fn brightness(&self) -> Result<u16> {
        self.get_brightness()
    }

    #[zbus(property, name = "Brightness")]
    pub async fn set_brightness_prop(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u16,
    ) -> Result<()> {
        self.set_brightness(value)?;
        let percentage = self.get_brightness_percentage()?;
        Self::emit_brightness_changed(&ctxt, percentage)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    #[zbus(property, name = "BrightnessPercentage")]
    pub fn brightness_percentage(&self) -> Result<u8> {
        self.get_brightness_percentage()
    }

    #[zbus(property, name = "BrightnessPercentage")]
    pub async fn set_brightness_percentage_prop(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u8,
    ) -> Result<()> {
        self.set_brightness_percentage(value)?;
        Self::emit_brightness_changed(&ctxt, value)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    #[zbus(property, name = "MaxBrightness")]
    pub fn get_max_brightness(&self) -> Result<u16> {
        Ok(self.max_brightness)
    }

    // Methods
    pub async fn increase_brightness(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u16,
    ) -> Result<()> {
        <Self as Brightness>::increase_brightness(self, value)?;
        Self::emit_brightness_changed(&ctxt, self.get_brightness_percentage()?)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    pub async fn decrease_brightness(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u16,
    ) -> Result<()> {
        <Self as Brightness>::decrease_brightness(self, value)?;
        Self::emit_brightness_changed(&ctxt, self.get_brightness_percentage()?)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    pub async fn increase_brightness_percentage(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u8,
    ) -> Result<()> {
        <Self as Brightness>::increase_brightness_percentage(self, value)?;
        Self::emit_brightness_changed(&ctxt, self.get_brightness_percentage()?)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    pub async fn decrease_brightness_percentage(
        &self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        value: u8,
    ) -> Result<()> {
        <Self as Brightness>::decrease_brightness_percentage(self, value)?;
        Self::emit_brightness_changed(&ctxt, self.get_brightness_percentage()?)
            .await
            .map_err(|e| Error::Failed(e.to_string()))
    }

    // Signals
    #[zbus(signal, name = "BrightnessChanged")]
    async fn emit_brightness_changed(ctxt: &SignalEmitter<'_>, percent: u8) -> zbus::Result<()>;
}
