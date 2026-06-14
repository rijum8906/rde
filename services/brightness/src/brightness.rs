use std::{fs, path::PathBuf, process::Command};

use zbus::{
    fdo::{Error, Result},
    interface,
};

use crate::constants::{BRIGHTNESS_FILE, BRIGHTNESS_HELPER_COMMAND, MAX_BRIGHTNESS_FILE};

pub trait Brightness {
    fn get_brightness(&self) -> Result<u16>;
    fn get_brightness_percent(&self) -> Result<u8>;
    fn set_brightness(&self, value: u16) -> Result<()>;
    fn set_brightness_percent(&self, value: u8) -> Result<()>;
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
}

impl BrightnessController {
    pub fn new(path: &str) -> Result<Self> {
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

        // Read max brightness
        let device_path = dir_entry.path();
        let max_path = device_path.join(MAX_BRIGHTNESS_FILE);
        let max_str = match fs::read_to_string(&max_path) {
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
        })
    }
}

#[interface(name = "org.rde.Brightness")]
impl BrightnessController {
    // get_brightness returns the current brightness
    pub fn get_brightness(&self) -> Result<u16> {
        let value_path = self.backlight_path.join(BRIGHTNESS_FILE);
        let max_str = match fs::read_to_string(&value_path) {
            Ok(s) => s,
            Err(e) => {
                return Err(zbus::fdo::Error::Failed(e.to_string()));
            }
        };

        // Parse and return
        match max_str.trim().parse() {
            Ok(u) => Ok(u),
            Err(_) => Err(zbus::fdo::Error::Failed(
                "Unsupported brightness value".to_string(),
            )),
        }
    }

    pub fn get_brightness_percent(&self) -> Result<u8> {
        let value = self.get_brightness()?;
        Ok((value as f64 / self.max_brightness as f64 * 100.0) as u8)
    }

    // set_brightness sets the current brightness
    pub fn set_brightness(&self, value: u16) -> Result<()> {
        // Check if value is in range
        if value > self.max_brightness {
            return Err(zbus::fdo::Error::Failed(
                "Unsupported brightness value".to_string(),
            ));
        }
        let value_path = self.backlight_path.join("brightness");
        let status = Command::new("pkexec")
            .arg(BRIGHTNESS_HELPER_COMMAND)
            .arg(value_path)
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

    pub fn set_brightness_percent(&self, value: u8) -> Result<()> {
        self.set_brightness((value as f64 / 100.0 * self.max_brightness as f64) as u16)
    }

    pub fn get_backlight_path(&self) -> &PathBuf {
        &self.backlight_path
    }

    pub fn get_max_brightness(&self) -> Result<u16> {
        Ok(self.max_brightness)
    }
}
