use std::{fs::read_dir, path::PathBuf, process::Command};

use rde_core::errors::{RdeError, RdeResult};

pub struct BrightnessBackend {
    pub backlight_path: PathBuf,
    pub brightness: u32,
    pub max_brightness: u32,
}

impl BrightnessBackend {
    pub fn new() -> RdeResult<Self> {
        // NOTE: For Laptop: /sys/class/backlight/{something}/
        // and there will be always one folder inside /sys/class/backlight/

        // get the backlight path
        let backlight_path = PathBuf::from("/sys/class/backlight/");

        // Check if directory exists
        if !backlight_path.exists() {
            return Err(RdeError::ConfigNotFound("No backlight found".to_string()));
        }

        // Read directory contents
        let entries = match read_dir(&backlight_path) {
            Ok(entries) => entries,
            Err(e) => return Err(RdeError::Io(e)),
        };

        // Count entries
        let mut count = 0;
        let mut first_entry = None;

        for entry in entries.flatten() {
            count += 1;
            if count == 1 {
                first_entry = Some(entry.path());
            }
        }

        if count == 0 {
            return Err(RdeError::ConfigNotFound("No backlight found".to_string()));
        }

        // Use the first entry
        if let Some(path) = first_entry {
            Ok(Self {
                backlight_path: path,
                max_brightness: 0,
                brightness: 0,
            })
        } else {
            Err(RdeError::ConfigNotFound("No backlight found".to_string()))
        }

        // TODO: desktop backlight
    }

    // set brightness and max brightness value
    pub fn init(&mut self) -> RdeResult<()> {
        let brightness_path = self.backlight_path.join("brightness");
        let brightness_max_path = self.backlight_path.join("max_brightness");

        let brightness = match std::fs::read_to_string(&brightness_path) {
            Ok(brightness) => brightness,
            Err(e) => return Err(RdeError::Io(e)),
        };
        let max_brightness = match std::fs::read_to_string(&brightness_max_path) {
            Ok(max_brightness) => max_brightness,
            Err(e) => return Err(RdeError::Io(e)),
        };

        self.brightness = brightness.trim().parse().unwrap_or(0);
        self.max_brightness = max_brightness.trim().parse().unwrap_or(0);

        Ok(())
    }

    pub fn get_brightness(&self) -> RdeResult<u32> {
        Ok(self.brightness)
    }

    pub fn set_brightness(&mut self, brightness: u32) -> RdeResult<()> {
        // Use pkexec to run the brightness helper with root privileges
        let output = Command::new("pkexec")
            .arg("/usr/bin/rde-brightness-helper")
            .arg(self.backlight_path.join("brightness"))
            .arg(brightness.to_string())
            .output()?;

        if output.status.success() {
            self.brightness = brightness;
            Ok(())
        } else {
            Err(RdeError::System(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ))
        }
    }

    pub fn get_max_brightness(&self) -> RdeResult<u32> {
        Ok(self.max_brightness)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new() {
        let result = BrightnessBackend::new();
        // Check if the result is Ok
        assert!(result.is_ok());
    }

    #[test]
    fn test_init() {
        let mut backend = BrightnessBackend::new().unwrap();
        let result = backend.init();

        // Check if the result is Ok
        assert!(result.is_ok());
        // get a proper value of brightness and max_brightness
        assert!(backend.brightness > 0);
        assert!(backend.max_brightness > 0);
    }
}
