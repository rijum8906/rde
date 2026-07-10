use std::{fs::read_dir, path::PathBuf, process::Command};

use rde_core::errors::{RdeError, RdeResult};

#[derive(Debug)]
pub struct BrightnessBackend {
    pub backlight_path: PathBuf,
    pub brightness: u32,
    pub max_brightness: u32,
}

impl BrightnessBackend {
    pub fn new() -> RdeResult<Self> {
        let backlight_path = PathBuf::from("/sys/class/backlight/");
        Self::new_with_path(backlight_path)
    }

    pub fn new_with_path(backlight_path: PathBuf) -> RdeResult<Self> {
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

    pub fn get_brightness_percent(&self) -> RdeResult<u32> {
        Ok((self.brightness * 100)
            .checked_div(self.max_brightness)
            .unwrap_or(0))
    }

    pub fn set_brightness(&mut self, brightness: u32) -> RdeResult<()> {
        let brightness_file = self.backlight_path.join("brightness");

        // Try writing directly first (saves pkexec overhead if the path is user-writable/mocked)
        if std::fs::write(&brightness_file, brightness.to_string()).is_ok() {
            self.brightness = brightness;
            return Ok(());
        }

        // Fallback to pkexec helper if direct write fails (e.g. in production without direct access)
        let output = Command::new("pkexec")
            .arg("/usr/bin/rde-brightness-helper")
            .arg(&brightness_file)
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
    fn test_new_with_path_non_existent() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-non-existent");
        let result = BrightnessBackend::new_with_path(temp_dir);
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), RdeError::ConfigNotFound(_)));
    }

    #[test]
    fn test_new_with_path_empty_directory() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-empty");
        std::fs::create_dir_all(&temp_dir).unwrap();

        let result = BrightnessBackend::new_with_path(temp_dir.clone());
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), RdeError::ConfigNotFound(_)));

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_new_with_path_success() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-success");
        let backlight_sub_dir = temp_dir.join("intel_backlight");
        std::fs::create_dir_all(&backlight_sub_dir).unwrap();

        let result = BrightnessBackend::new_with_path(temp_dir.clone());
        assert!(result.is_ok());
        let backend = result.unwrap();
        assert_eq!(backend.backlight_path, backlight_sub_dir);

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_init_success() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-init-success");
        let backlight_sub_dir = temp_dir.join("amdgpu_bl0");
        std::fs::create_dir_all(&backlight_sub_dir).unwrap();

        std::fs::write(backlight_sub_dir.join("brightness"), "45\n").unwrap();
        std::fs::write(backlight_sub_dir.join("max_brightness"), "255\n").unwrap();

        let mut backend = BrightnessBackend {
            backlight_path: backlight_sub_dir,
            brightness: 0,
            max_brightness: 0,
        };

        let result = backend.init();
        assert!(result.is_ok());
        assert_eq!(backend.brightness, 45);
        assert_eq!(backend.max_brightness, 255);

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_init_missing_brightness() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-init-missing-brightness");
        let backlight_sub_dir = temp_dir.join("amdgpu_bl0");
        std::fs::create_dir_all(&backlight_sub_dir).unwrap();

        std::fs::write(backlight_sub_dir.join("max_brightness"), "255\n").unwrap();

        let mut backend = BrightnessBackend {
            backlight_path: backlight_sub_dir,
            brightness: 0,
            max_brightness: 0,
        };

        let result = backend.init();
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), RdeError::Io(_)));

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_init_missing_max_brightness() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-init-missing-max");
        let backlight_sub_dir = temp_dir.join("amdgpu_bl0");
        std::fs::create_dir_all(&backlight_sub_dir).unwrap();

        std::fs::write(backlight_sub_dir.join("brightness"), "120\n").unwrap();

        let mut backend = BrightnessBackend {
            backlight_path: backlight_sub_dir,
            brightness: 0,
            max_brightness: 0,
        };

        let result = backend.init();
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), RdeError::Io(_)));

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_getters_and_setters() {
        let temp_dir = std::env::temp_dir().join("rde-brightness-test-getters-setters");
        let backlight_sub_dir = temp_dir.join("intel_backlight");
        std::fs::create_dir_all(&backlight_sub_dir).unwrap();

        std::fs::write(backlight_sub_dir.join("brightness"), "50\n").unwrap();
        std::fs::write(backlight_sub_dir.join("max_brightness"), "100\n").unwrap();

        let mut backend = BrightnessBackend {
            backlight_path: backlight_sub_dir.clone(),
            brightness: 50,
            max_brightness: 100,
        };

        assert_eq!(backend.get_brightness().unwrap(), 50);
        assert_eq!(backend.get_brightness_percent().unwrap(), 50);
        assert_eq!(backend.get_max_brightness().unwrap(), 100);

        // set_brightness should succeed via direct write because the temp file is user-writable
        let set_result = backend.set_brightness(80);
        assert!(set_result.is_ok());

        assert_eq!(backend.get_brightness().unwrap(), 80);
        assert_eq!(backend.get_brightness_percent().unwrap(), 80);

        // Verify the mock file content was actually updated
        let file_content = std::fs::read_to_string(backlight_sub_dir.join("brightness")).unwrap();
        assert_eq!(file_content.trim(), "80");

        let _ = std::fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_get_brightness_percent_zero_max() {
        let backend = BrightnessBackend {
            backlight_path: PathBuf::new(),
            brightness: 50,
            max_brightness: 0,
        };
        assert_eq!(backend.get_brightness_percent().unwrap(), 0);
    }
}
