use chrono::Utc;
use rde_core::errors::{RdeError, RdeResult};
use std::collections::HashMap;

use super::WifiBackend;
use crate::infra::dbus::{DeviceProxy, WirelessProxy};

impl WifiBackend {
    /// Scans the network devices on the system and selects the first device of type
    /// Wi-Fi (DeviceType 2) as the active device.
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

    /// Helper method to retrieve the Wireless proxy for the active Wi-Fi device.
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

    /// Enables or disables the Wi-Fi radio.
    pub async fn set_wifi_enabled(&self, enabled: bool) -> RdeResult<()> {
        self.nm_proxy
            .set_wireless_enabled(enabled)
            .await
            .map_err(RdeError::Dbus)?;
        Ok(())
    }

    /// Checks if the Wi-Fi radio is enabled.
    pub async fn is_wifi_enabled(&self) -> RdeResult<bool> {
        let enabled = self
            .nm_proxy
            .wireless_enabled()
            .await
            .map_err(RdeError::Dbus)?;
        Ok(enabled)
    }

    /// Requests a Wi-Fi scan on the active device.
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
