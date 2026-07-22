//! # Wi-Fi Device Management Module
//!
//! This module manages NetworkManager Wi-Fi hardware device detection, device proxy creation,
//! enabling/disabling the Wi-Fi radio, and triggering asynchronous network scans.

use chrono::Utc;
use rde_core::errors::{RdeError, RdeResult};
use std::collections::HashMap;

use super::WifiBackend;
use crate::infra::dbus::{DeviceProxy, WirelessProxy};

impl WifiBackend {
    /// Scans network interfaces registered with NetworkManager on the host system
    /// and selects the first wireless device (DeviceType = 2, i.e., `NM_DEVICE_TYPE_WIFI`)
    /// as the active target hardware interface.
    ///
    /// # Process
    /// 1. Queries NetworkManager via `get_all_devices()` D-Bus method to list device object paths.
    /// 2. Instantiates a `DeviceProxy` for each path resiliently (skipping disconnected or missing interfaces).
    /// 3. Inspects the device hardware type using `device_type()`.
    /// 4. When a Wi-Fi device (`DeviceType == 2`) is found, caches its path and proxy object in `WifiBackend`.
    ///
    /// # Errors
    /// Returns `RdeError` if communication with NetworkManager fails.
    pub async fn scan_wifi_devices(&mut self) -> RdeResult<()> {
        // Step 1: Query the list of all network device object paths from NetworkManager
        let devices = self.nm_proxy.get_all_devices().await?;
        let connection = &self.connection;

        // Step 2: Iterate through each device path to identify the Wi-Fi interface
        for device_path in devices {
            // Instantiate a DeviceProxy for the specific D-Bus object path.
            // If creation fails (e.g., if a device was unplugged or permissions are missing),
            // log a warning and continue resiliently instead of panicking or failing.
            let device = match DeviceProxy::new(connection, device_path.clone()).await {
                Ok(d) => d,
                Err(e) => {
                    tracing::warn!("Failed to create device proxy for path: {}", e);
                    continue; // Skip this device and evaluate the next one
                }
            };

            // Query the device's hardware type from the NetworkManager service.
            // Again, if this call fails, log a warning and proceed.
            let device_type = match device.device_type().await {
                Ok(t) => t,
                Err(e) => {
                    tracing::warn!("Failed to query device type: {}", e);
                    continue; // Skip this device and evaluate the next one
                }
            };

            // Step 3: Match against NetworkManager's standard DeviceType enum.
            // Value 2 corresponds to NM_DEVICE_TYPE_WIFI.
            if device_type == 2 {
                // Cache the matched Wi-Fi device path and proxy, and record the initialization timestamp.
                self.current_device_path = Some(device_path);
                self.current_device = Some(device);
                self.last_scaned_at = Utc::now();
                return Ok(()); // Wi-Fi device successfully found; exit init early
            }
        }

        // If we iterate through all devices without finding a Wi-Fi interface,
        // record the timestamp and return Ok(()) (service starts in a disconnected/no-device state).
        self.last_scaned_at = Utc::now();
        Ok(())
    }

    /// Helper method to retrieve the `WirelessProxy` interface for the active Wi-Fi device.
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if no active Wi-Fi device path is cached,
    /// or `RdeError::Dbus` if D-Bus proxy construction fails.
    pub(super) async fn get_wireless_proxy(&self) -> RdeResult<WirelessProxy<'static>> {
        let path = self
            .current_device_path
            .as_ref()
            .ok_or_else(|| RdeError::ConfigNotFound("No Wi-Fi device active".to_string()))?;
        let wireless = WirelessProxy::new(&self.connection, path.clone())
            .await
            .map_err(RdeError::Dbus)?;
        Ok(wireless)
    }

    /// Enables or disables the global Wi-Fi wireless radio on the system via NetworkManager.
    ///
    /// # Parameters
    /// - `enabled`: `true` to turn Wi-Fi radio on, `false` to turn it off.
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` if setting the D-Bus property fails.
    pub async fn set_wifi_enabled(&self, enabled: bool) -> RdeResult<()> {
        self.nm_proxy
            .set_wireless_enabled(enabled)
            .await
            .map_err(RdeError::Dbus)?;
        Ok(())
    }

    /// Checks whether the global Wi-Fi wireless radio is enabled on the system.
    ///
    /// # Returns
    /// - `Ok(true)` if Wi-Fi radio is powered on.
    /// - `Ok(false)` if Wi-Fi radio is powered off (airplane mode).
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` if querying NetworkManager fails.
    pub async fn is_wifi_enabled(&self) -> RdeResult<bool> {
        let enabled = self
            .nm_proxy
            .wireless_enabled()
            .await
            .map_err(RdeError::Dbus)?;
        Ok(enabled)
    }

    /// Requests an asynchronous Wi-Fi scan on the active wireless device.
    ///
    /// NetworkManager will trigger a background spectrum scan for access points.
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if no active Wi-Fi device is present,
    /// or `RdeError::Dbus` if the D-Bus method call fails.
    pub async fn request_scan(&self) -> RdeResult<()> {
        let wireless = self.get_wireless_proxy().await?;
        let options = HashMap::new();
        wireless
            .request_scan(options)
            .await
            .map_err(RdeError::Dbus)?;
        Ok(())
    }
}
