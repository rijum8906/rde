//! # Brightness D-Bus Interface Implementation
//!
//! Implements the D-Bus object interface exposing brightness control capabilities.
//! Provides properties, methods, and signals for remote brightness management.
//!
//! ## Features
//! - Raw brightness value access (hardware-dependent scale)
//! - Percentage-based brightness adjustment (0-100%)
//! - Incremental brightness changes (step-based increase/decrease)
//! - Signal emission on brightness changes
//! - Comprehensive error logging and reporting
//!
//! ## Related
//! - [`crate::backend::BrightnessBackend`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use crate::backend::BrightnessBackend;
use rde_core::{errors::RdeResult, logger::Logger};
use tracing::{debug, error, info};
use zbus::interface;

/// Brightness D-Bus interface handler.
///
/// Exposes brightness control through D-Bus at `/org/rde/Brightness` with interface `org.rde.Brightness`.
/// Manages both raw and percentage-based brightness values while coordinating with hardware backend.
#[derive(Debug)]
pub struct BrightnessInterface {
    /// Hardware abstraction layer for backlight control
    pub backend: BrightnessBackend,

    /// Logger instance for structured logging
    pub logger: Logger,
}

impl BrightnessInterface {
    /// Creates a new `BrightnessInterface` instance.
    ///
    /// # Workflow
    /// 1. Receives logger from application
    /// 2. Initializes hardware backend
    /// 3. Reads current brightness values from hardware
    /// 4. Prepares D-Bus object for registration
    ///
    /// # Parameters
    /// - `logger`: Logger instance for service logging
    ///
    /// # Errors
    /// Returns `RdeError` if:
    /// - Backend initialization fails (no backlight hardware found)
    /// - Hardware brightness values cannot be read
    pub fn new(logger: Logger) -> RdeResult<Self> {
        info!("Initializing Brightness D-Bus interface...");

        // Create an instance of the backend
        let mut backend = BrightnessBackend::new()?;

        // Initialize the backend (read current brightness from hardware)
        backend.init()?;

        debug!(
            "Backend initialized: {}% brightness",
            backend.get_brightness_percent().unwrap_or(0)
        );

        Ok(Self { backend, logger })
    }
}

#[interface(name = "org.rde.Brightness")]
impl BrightnessInterface {
    // ========= PROPERTIES ==========

    /// Service version string.
    ///
    /// Returns the semantic version from Cargo.toml (e.g., "0.1.0").
    /// This is a read-only property.
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        let version = env!("CARGO_PKG_VERSION");
        debug!("Version property accessed: {}", version);
        Ok(version.to_string())
    }

    /// Raw brightness value (hardware-dependent scale).
    ///
    /// Returns the current brightness on the hardware-specific scale
    /// (typically 0-255, 0-4096, etc. depending on backlight driver).
    ///
    /// # Properties
    /// - Read-Only (emits_changed_signal = "false")
    /// - To change brightness, use the property setter or methods
    ///
    /// # Errors
    /// Returns D-Bus error if backend fails to read brightness
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness(&self) -> zbus::fdo::Result<u32> {
        match self.backend.get_brightness() {
            Ok(value) => {
                debug!("Raw brightness property accessed: {}", value);
                Ok(value)
            }
            Err(e) => {
                error!("Failed to get raw brightness: {}", e);
                Err(zbus::fdo::Error::Failed(e.to_string()))
            }
        }
    }

    /// Sets the raw brightness value.
    ///
    /// # Workflow
    /// 1. Sets brightness to raw value via backend
    /// 2. Calculates current percentage for signal
    /// 3. Emits BrightnessChanged signal with percentage
    ///
    /// # Parameters
    /// - `brightness`: New raw brightness value
    ///
    /// # Errors
    /// Returns D-Bus error if backend write fails
    ///
    /// # Signals
    /// Emits `BrightnessChanged` with percentage value
    #[zbus(property)]
    pub async fn set_brightness(
        &mut self,
        brightness: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        info!("Setting raw brightness to {}", brightness);

        self.backend.set_brightness(brightness).map_err(|e| {
            error!("Failed to set raw brightness to {}: {}", brightness, e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        // Calculate current percent to emit signal with percentage
        let percent = self.backend.get_brightness_percent().map_err(|e| {
            error!("Failed to get brightness percentage after set: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        // Emit custom BrightnessChanged signal with new percentage
        Self::emit_brightness_changed(&emitter, percent)
            .await
            .map_err(|e| {
                error!("Failed to emit BrightnessChanged signal: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })?;

        Ok(())
    }

    /// Current brightness as a percentage (0-100%).
    ///
    /// Returns the brightness normalized to 0-100% range.
    /// Calculation: `(raw_brightness * 100) / max_brightness`
    ///
    /// # Properties
    /// - Read-Only (emits_changed_signal = "false")
    /// - To change brightness, use the property setter or methods
    ///
    /// # Errors
    /// Returns D-Bus error if backend fails to calculate percentage
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn brightness_percentage(&self) -> zbus::fdo::Result<u32> {
        match self.backend.get_brightness_percent() {
            Ok(percent) => {
                debug!("Brightness percentage property accessed: {}%", percent);
                Ok(percent)
            }
            Err(e) => {
                error!("Failed to get brightness percentage: {}", e);
                Err(zbus::fdo::Error::Failed(e.to_string()))
            }
        }
    }

    /// Sets the brightness as a percentage (0-100%).
    ///
    /// # Workflow
    /// 1. Converts percentage to raw value using: `raw = (percent * max) / 100`
    /// 2. Sets brightness via backend
    /// 3. Emits BrightnessChanged signal
    ///
    /// # Parameters
    /// - `percent`: New brightness percentage (0-100)
    ///
    /// # Errors
    /// Returns D-Bus error if backend write fails
    ///
    /// # Signals
    /// Emits `BrightnessChanged` with requested percentage
    #[zbus(property)]
    pub async fn set_brightness_percentage(
        &mut self,
        percent: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        info!("Setting brightness to {}%", percent);

        let max = self.backend.max_brightness;
        let raw_val = (percent * max) / 100;

        debug!(
            "Converting {}% to raw value {} (max: {})",
            percent, raw_val, max
        );

        self.backend.set_brightness(raw_val).map_err(|e| {
            error!("Failed to set brightness to {}%: {}", percent, e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        // Emit custom BrightnessChanged signal
        Self::emit_brightness_changed(&emitter, percent)
            .await
            .map_err(|e| {
                error!("Failed to emit BrightnessChanged signal: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })?;

        Ok(())
    }

    /// Maximum supported brightness value.
    ///
    /// Returns the hardware-specific maximum brightness value.
    /// This is used to normalize percentage calculations.
    ///
    /// # Properties
    /// - Read-Only (emits_changed_signal = "false")
    /// - Value determined at hardware initialization and never changes
    ///
    /// # Errors
    /// Returns D-Bus error if backend fails to retrieve value
    #[zbus(property(emits_changed_signal = "false"))]
    pub fn max_brightness(&self) -> zbus::fdo::Result<u32> {
        match self.backend.get_max_brightness() {
            Ok(value) => {
                debug!("Max brightness property accessed: {}", value);
                Ok(value)
            }
            Err(e) => {
                error!("Failed to get max brightness: {}", e);
                Err(zbus::fdo::Error::Failed(e.to_string()))
            }
        }
    }

    // ========= METHODS ==========

    /// Increase brightness by the specified step percentage.
    ///
    /// # Workflow
    /// 1. Gets current brightness percentage
    /// 2. Adds step value (clamped to maximum of 100%)
    /// 3. Sets new brightness value
    /// 4. Emits BrightnessChanged signal
    /// 5. Returns new brightness percentage
    ///
    /// # Parameters
    /// - `step`: Percentage points to increase (0-100)
    ///
    /// # Returns
    /// New brightness percentage after increase
    ///
    /// # Clamping
    /// New brightness is clamped to 100% maximum
    ///
    /// # Errors
    /// Returns D-Bus error if brightness read/write fails
    ///
    /// # Signals
    /// Emits `BrightnessChanged` with new percentage
    ///
    /// # Example
    /// If current brightness is 60% and step is 20%:
    /// - Result: 80%
    ///
    /// If current brightness is 90% and step is 20%:
    /// - Result: 100% (clamped)
    #[zbus(name = "IncreaseBrightness")]
    pub async fn increase_brightness(
        &mut self,
        step: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        info!("IncreaseBrightness method called with step: {}%", step);

        let current_percent = self.backend.get_brightness_percent().map_err(|e| {
            error!("Failed to get current brightness percentage: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        let new_percent = std::cmp::min(current_percent + step, 100);
        info!(
            "Increasing brightness: {}% -> {}%",
            current_percent, new_percent
        );

        let max = self.backend.max_brightness;
        let raw_val = (new_percent * max) / 100;

        self.backend.set_brightness(raw_val).map_err(|e| {
            error!("Failed to set brightness to {}%: {}", new_percent, e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        Self::emit_brightness_changed(&emitter, new_percent)
            .await
            .map_err(|e| {
                error!("Failed to emit BrightnessChanged signal: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })?;

        debug!("Brightness increased to {}%", new_percent);
        Ok(new_percent)
    }

    /// Decrease brightness by the specified step percentage.
    ///
    /// # Workflow
    /// 1. Gets current brightness percentage
    /// 2. Subtracts step value (clamped to minimum of 0%)
    /// 3. Sets new brightness value
    /// 4. Emits BrightnessChanged signal
    /// 5. Returns new brightness percentage
    ///
    /// # Parameters
    /// - `step`: Percentage points to decrease (0-100)
    ///
    /// # Returns
    /// New brightness percentage after decrease
    ///
    /// # Saturation
    /// New brightness is saturated to 0% minimum (no underflow)
    ///
    /// # Errors
    /// Returns D-Bus error if brightness read/write fails
    ///
    /// # Signals
    /// Emits `BrightnessChanged` with new percentage
    ///
    /// # Example
    /// If current brightness is 60% and step is 20%:
    /// - Result: 40%
    ///
    /// If current brightness is 10% and step is 20%:
    /// - Result: 0% (saturated)
    #[zbus(name = "DecreaseBrightness")]
    pub async fn decrease_brightness(
        &mut self,
        step: u32,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<u32> {
        info!("DecreaseBrightness method called with step: {}%", step);

        let current_percent = self.backend.get_brightness_percent().map_err(|e| {
            error!("Failed to get current brightness percentage: {}", e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        let new_percent = current_percent.saturating_sub(step);
        info!(
            "Decreasing brightness: {}% -> {}%",
            current_percent, new_percent
        );

        let max = self.backend.max_brightness;
        let raw_val = (new_percent * max) / 100;

        self.backend.set_brightness(raw_val).map_err(|e| {
            error!("Failed to set brightness to {}%: {}", new_percent, e);
            zbus::fdo::Error::Failed(e.to_string())
        })?;

        Self::emit_brightness_changed(&emitter, new_percent)
            .await
            .map_err(|e| {
                error!("Failed to emit BrightnessChanged signal: {}", e);
                zbus::fdo::Error::Failed(e.to_string())
            })?;

        debug!("Brightness decreased to {}%", new_percent);
        Ok(new_percent)
    }

    // ========= SIGNALS ==========

    /// Emitted when brightness value changes.
    ///
    /// Signal is emitted after any successful brightness change via:
    /// - Property setters (brightness, brightness_percentage)
    /// - Method calls (IncreaseBrightness, DecreaseBrightness)
    ///
    /// # Parameters
    /// - `percent`: New brightness percentage (0-100)
    ///
    /// # Listeners
    /// D-Bus clients subscribe to this signal to be notified of brightness changes
    /// from any source (D-Bus methods, hardware buttons, other clients, etc.)
    #[zbus(signal, name = "BrightnessChanged")]
    pub async fn emit_brightness_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        percent: u32,
    ) -> zbus::Result<()>;
}
