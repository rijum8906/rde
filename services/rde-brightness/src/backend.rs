//! # Brightness Hardware Backend
//!
//! Provides low-level hardware abstraction for display backlight control via sysfs interface.
//! Supports multiple graphics hardware vendors including Intel, AMD, and generic Linux backlight drivers.
//!
//! ## Features
//! - Direct sysfs backlight reading and writing
//! - Graceful fallback to privilege escalation (pkexec) when direct access fails
//! - Percentage-based brightness calculation (0-100%)
//! - Hardware-agnostic backlight driver detection
//! - Comprehensive error handling and logging
//!
//! ## Sysfs Interface
//! Brightness control is performed via `/sys/class/backlight/<driver>/` interface:
//! - `brightness`: Current raw brightness value (0 to max_brightness)
//! - `max_brightness`: Maximum supported brightness value
//!
//! ## Supported Drivers
//! - `intel_backlight`: Intel display backlight
//! - `amdgpu_bl0`, `amdgpu_bl1`: AMD/AMDGPU display backlight
//! - `acpi_video0`, `acpi_video1`: Generic ACPI backlight
//! - Other platform-specific backlight drivers
//!
//! ## Privilege Escalation
//! When direct sysfs write fails, the backend attempts privilege escalation via:
//! ```bash
//! pkexec /usr/bin/rde-brightness-helper <path> <value>
//! ```
//! This requires proper PolicyKit configuration for desktop environments.
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{fs::read_dir, path::PathBuf, process::Command};

use rde_core::errors::{RdeError, RdeResult};

/// Hardware abstraction for display backlight brightness control.
///
/// Manages interaction with Linux kernel backlight drivers via sysfs interface.
/// Automatically detects available backlight hardware during initialization.
#[derive(Debug)]
pub struct BrightnessBackend {
    /// Path to the backlight driver directory (e.g., `/sys/class/backlight/intel_backlight/`)
    pub backlight_path: PathBuf,

    /// Current brightness raw value (hardware-dependent scale, typically 0-255 or 0-4096)
    pub brightness: u32,

    /// Maximum supported brightness value for the hardware
    pub max_brightness: u32,
}

impl BrightnessBackend {
    /// Creates a new `BrightnessBackend` by auto-detecting the first available backlight driver.
    ///
    /// # Workflow
    /// 1. Searches `/sys/class/backlight/` for available backlight drivers
    /// 2. Uses the first driver found (typically intel_backlight, amdgpu_bl0, etc.)
    /// 3. Returns error if no backlight drivers are found
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if:
    /// - `/sys/class/backlight/` directory doesn't exist
    /// - No backlight drivers are found in the directory
    pub fn new() -> RdeResult<Self> {
        let backlight_path = PathBuf::from("/sys/class/backlight/");
        tracing::debug!("Searching for backlight drivers in: {:?}", backlight_path);
        Self::new_with_path(backlight_path)
    }

    /// Creates a new `BrightnessBackend` with a custom backlight directory path.
    ///
    /// # Parameters
    /// - `backlight_path`: Path to the backlight drivers directory (typically `/sys/class/backlight/`)
    ///
    /// # Workflow
    /// 1. Validates that the path exists and is readable
    /// 2. Scans directory for backlight driver subdirectories
    /// 3. Selects the first available driver
    /// 4. Records driver-specific sysfs path for later access
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if:
    /// - Directory path doesn't exist
    /// - Directory is empty (no backlight drivers found)
    /// - Directory read fails
    pub fn new_with_path(backlight_path: PathBuf) -> RdeResult<Self> {
        // Validate directory exists
        if !backlight_path.exists() {
            tracing::error!("Backlight directory not found: {:?}", backlight_path);
            return Err(RdeError::ConfigNotFound(format!(
                "No backlight found at {:?}",
                backlight_path
            )));
        }

        // Read directory contents
        let entries = match read_dir(&backlight_path) {
            Ok(entries) => entries,
            Err(e) => {
                tracing::error!("Failed to read backlight directory: {}", e);
                return Err(RdeError::Io(e));
            }
        };

        // Find first available backlight driver
        let mut count = 0;
        let mut first_entry = None;

        for entry in entries.flatten() {
            count += 1;
            if count == 1 {
                first_entry = Some(entry.path());
                tracing::debug!("Found backlight driver: {:?}", first_entry);
            }
        }

        if count == 0 {
            tracing::error!("No backlight drivers found in {:?}", backlight_path);
            return Err(RdeError::ConfigNotFound(
                "No backlight drivers found".to_string(),
            ));
        }

        if let Some(path) = first_entry {
            tracing::info!("Using backlight driver: {:?}", path);
            Ok(Self {
                backlight_path: path,
                max_brightness: 0,
                brightness: 0,
            })
        } else {
            Err(RdeError::ConfigNotFound("No backlight found".to_string()))
        }
    }

    /// Initializes the backend by reading current brightness values from sysfs.
    ///
    /// # Workflow
    /// 1. Reads current brightness value from `brightness` file
    /// 2. Reads maximum brightness value from `max_brightness` file
    /// 3. Parses values and caches them in struct
    /// 4. Handles parsing errors gracefully with defaults
    ///
    /// # Errors
    /// Returns `RdeError::Io` if:
    /// - `brightness` file cannot be read
    /// - `max_brightness` file cannot be read
    ///
    /// # Logging
    /// - DEBUG: File paths being read, values successfully parsed
    /// - INFO: Initialization complete with brightness state
    /// - WARN: Fallback to default values (0) on parse errors
    pub fn init(&mut self) -> RdeResult<()> {
        let brightness_path = self.backlight_path.join("brightness");
        let brightness_max_path = self.backlight_path.join("max_brightness");

        tracing::debug!(
            "Initializing brightness backend from: {:?}, {:?}",
            brightness_path,
            brightness_max_path
        );

        let brightness = match std::fs::read_to_string(&brightness_path) {
            Ok(brightness) => {
                tracing::debug!("Successfully read brightness file");
                brightness
            }
            Err(e) => {
                tracing::error!("Failed to read brightness file: {}", e);
                return Err(RdeError::Io(e));
            }
        };

        let max_brightness = match std::fs::read_to_string(&brightness_max_path) {
            Ok(max_brightness) => {
                tracing::debug!("Successfully read max_brightness file");
                max_brightness
            }
            Err(e) => {
                tracing::error!("Failed to read max_brightness file: {}", e);
                return Err(RdeError::Io(e));
            }
        };

        // Parse values with fallback to 0 on error
        self.brightness = brightness.trim().parse().unwrap_or_else(|e| {
            tracing::warn!("Failed to parse brightness value, using 0: {}", e);
            0
        });
        self.max_brightness = max_brightness.trim().parse().unwrap_or_else(|e| {
            tracing::warn!("Failed to parse max_brightness value, using 0: {}", e);
            0
        });

        tracing::info!(
            "Brightness backend initialized: {}% (raw: {}/{})",
            self.get_brightness_percent().unwrap_or(0),
            self.brightness,
            self.max_brightness
        );

        Ok(())
    }

    /// Retrieves the current raw brightness value.
    ///
    /// # Returns
    /// Current brightness value on the hardware-specific scale (e.g., 0-255, 0-4096)
    ///
    /// # Errors
    /// Never fails; always succeeds with cached value
    pub fn get_brightness(&self) -> RdeResult<u32> {
        Ok(self.brightness)
    }

    /// Calculates and returns the brightness as a percentage (0-100%).
    ///
    /// # Calculation
    /// `percentage = (brightness * 100) / max_brightness`
    ///
    /// # Returns
    /// Brightness percentage (0-100) rounded down via integer division
    ///
    /// # Edge Cases
    /// Returns 0 if `max_brightness` is 0 (division by zero protection)
    pub fn get_brightness_percent(&self) -> RdeResult<u32> {
        Ok((self.brightness * 100)
            .checked_div(self.max_brightness)
            .unwrap_or(0))
    }

    /// Sets the brightness to a raw value and updates sysfs.
    ///
    /// # Workflow
    /// 1. Attempts direct sysfs write first (faster, no privilege escalation)
    /// 2. On failure, falls back to pkexec privilege escalation
    /// 3. Updates internal cache after successful write
    ///
    /// # Parameters
    /// - `brightness`: New raw brightness value (should be 0 to max_brightness)
    ///
    /// # Errors
    /// Returns `RdeError::System` if:
    /// - Direct write fails AND
    /// - pkexec helper also fails to set brightness
    ///
    /// # Logging
    /// - DEBUG: Direct write attempt
    /// - INFO: Successful brightness change with old/new values
    /// - WARN: Direct write failed, falling back to pkexec
    /// - ERROR: Both direct and privileged write failed
    pub fn set_brightness(&mut self, brightness: u32) -> RdeResult<()> {
        let brightness_file = self.backlight_path.join("brightness");

        tracing::debug!(
            "Attempting to set brightness to {} (raw) at {:?}",
            brightness,
            brightness_file
        );

        // Try writing directly first (saves pkexec overhead if the path is user-writable)
        if std::fs::write(&brightness_file, brightness.to_string()).is_ok() {
            self.brightness = brightness;
            let percent = self.get_brightness_percent().unwrap_or(0);
            tracing::info!(
                "Successfully set brightness to {}% (raw: {})",
                percent,
                brightness
            );
            return Ok(());
        }

        // Fallback to pkexec helper if direct write fails (production without direct access)
        tracing::warn!("Direct sysfs write failed, attempting privilege escalation via pkexec");

        let output = Command::new("pkexec")
            .arg("/usr/bin/rde-brightness-helper")
            .arg(&brightness_file)
            .arg(brightness.to_string())
            .output()?;

        if output.status.success() {
            self.brightness = brightness;
            let percent = self.get_brightness_percent().unwrap_or(0);
            tracing::info!(
                "Successfully set brightness via pkexec to {}% (raw: {})",
                percent,
                brightness
            );
            Ok(())
        } else {
            let error_msg = String::from_utf8_lossy(&output.stderr).to_string();
            tracing::error!("Privileged brightness write failed: {}", error_msg);
            Err(RdeError::System(error_msg))
        }
    }

    /// Retrieves the maximum supported brightness value.
    ///
    /// # Returns
    /// Hardware-specific maximum brightness (typically 255, 4096, etc.)
    ///
    /// # Errors
    /// Never fails; always succeeds with cached value
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
