use chrono::{DateTime, Utc};
use rde_core::errors::{RdeError, RdeResult};
use std::collections::HashMap;
use zbus::Connection;
use zbus::zvariant::OwnedObjectPath;

use crate::infra::dbus::{
    AccessPointProxy, ConnectionSettingsProxy, DeviceProxy, NetworkManagerProxy, SettingsProxy,
    WirelessProxy,
};

/// Backend service for managing Wi-Fi state and NetworkManager interactions.
///
/// It establishes and maintains a system D-Bus connection to the `org.freedesktop.NetworkManager`
/// service and caches proxy objects for communication.
#[allow(dead_code)]
pub struct WifiBackend {
    /// The core system D-Bus connection.
    connection: Connection,
    /// Proxy object for the main NetworkManager D-Bus interface.
    pub nm_proxy: NetworkManagerProxy<'static>,

    /// Cache of device proxies currently available on the system.
    devices: Option<Vec<DeviceProxy<'static>>>,
    /// Cache of the currently active Wi-Fi device proxy, if found.
    current_device: Option<DeviceProxy<'static>>,
    /// Cache of the active Wi-Fi device D-Bus object path.
    current_device_path: Option<OwnedObjectPath>,

    /// Timestamp indicating when the last network scan or query was performed.
    last_scaned_at: DateTime<Utc>,
}

impl WifiBackend {
    /// Constructs a new `WifiBackend` instance by establishing a connection
    /// to the system D-Bus and initializing the backend state.
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` if the D-Bus connection cannot be established
    /// or if proxy creation fails.
    pub async fn new() -> RdeResult<Self> {
        // Connect to the system bus where NetworkManager is located
        let connection = Connection::system().await.map_err(RdeError::Dbus)?;
        let network_manager_proxy = NetworkManagerProxy::new(&connection).await?;

        let mut me = Self {
            connection,
            nm_proxy: network_manager_proxy,
            devices: None,
            current_device: None,
            current_device_path: None,
            last_scaned_at: Utc::now(),
        };

        // Scan and detect the primary Wi-Fi device
        me.scan_wifi_device().await?;

        Ok(me)
    }

    /// Scans the network devices on the system and selects the first device of type
    /// Wi-Fi (DeviceType 2) as the active device.
    ///
    /// # Errors
    /// Returns `RdeError` if communication with NetworkManager fails.
    pub async fn scan_wifi_device(&mut self) -> RdeResult<()> {
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
    async fn get_wireless_proxy(&self) -> RdeResult<WirelessProxy<'static>> {
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

    /// Retrieves all visible Wi-Fi access points.
    pub async fn get_available_networks(
        &self,
    ) -> RdeResult<Vec<crate::domain::models::AccessPointInfo>> {
        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;

        let mut aps = Vec::new();
        let connection = &self.connection;

        let active_ap_path = wireless.active_access_point().await.ok();

        for path in ap_paths {
            let ap_proxy = match AccessPointProxy::new(connection, path.clone()).await {
                Ok(proxy) => proxy,
                Err(e) => {
                    tracing::warn!("Failed to create AccessPoint proxy: {}", e);
                    continue;
                }
            };

            let mac_address = ap_proxy.hw_address().await.unwrap_or_default();
            let frequency = ap_proxy.frequency().await.unwrap_or_default();
            let strength = ap_proxy.strength().await.unwrap_or_default();
            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
            let ssid = String::from_utf8_lossy(&ssid_bytes).into_owned();

            if ssid.is_empty() {
                continue;
            }

            let flags = ap_proxy.flags().await.unwrap_or_default();
            let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or_default();
            let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or_default();
            let security = determine_security_type(flags, wpa_flags, rsn_flags);

            let is_connected = Some(&path) == active_ap_path.as_ref();

            aps.push(crate::domain::models::AccessPointInfo {
                path: path.as_str().to_string(),
                ssid,
                strength,
                security,
                mac_address,
                frequency,
                is_connected,
                is_saved: false,
            });
        }

        aps.sort_by_key(|b| std::cmp::Reverse(b.strength));
        Ok(aps)
    }

    /// Gets the details of the currently connected Wi-Fi access point.
    pub async fn get_current_connection(
        &self,
    ) -> RdeResult<Option<crate::domain::models::AccessPointInfo>> {
        let wireless = self.get_wireless_proxy().await?;
        let active_ap_path = wireless
            .active_access_point()
            .await
            .map_err(RdeError::Dbus)?;

        if active_ap_path.as_str() == "/" {
            return Ok(None);
        }

        let connection = &self.connection;
        let ap_proxy = AccessPointProxy::new(connection, active_ap_path.clone())
            .await
            .map_err(RdeError::Dbus)?;

        let mac_address = ap_proxy.hw_address().await.unwrap_or_default();
        let frequency = ap_proxy.frequency().await.unwrap_or_default();
        let strength = ap_proxy.strength().await.unwrap_or_default();
        let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
        let ssid = String::from_utf8_lossy(&ssid_bytes).into_owned();

        let flags = ap_proxy.flags().await.unwrap_or_default();
        let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or_default();
        let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or_default();
        let security = determine_security_type(flags, wpa_flags, rsn_flags);

        Ok(Some(crate::domain::models::AccessPointInfo {
            path: active_ap_path.as_str().to_string(),
            ssid,
            strength,
            security,
            mac_address,
            frequency,
            is_connected: true,
            is_saved: true,
        }))
    }

    /// Connects to a Wi-Fi network with the given SSID and optional password.
    pub async fn connect_to_network(&self, ssid: &str, password: Option<&str>) -> RdeResult<()> {
        let device_path = self
            .current_device_path
            .as_ref()
            .ok_or_else(|| RdeError::ConfigNotFound("No Wi-Fi device active".to_string()))?;

        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;
        let connection = &self.connection;

        let mut target_ap_path = None;
        for path in ap_paths {
            let ap_proxy = match AccessPointProxy::new(connection, path.clone()).await {
                Ok(p) => p,
                Err(_) => continue,
            };
            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
            let ap_ssid = String::from_utf8_lossy(&ssid_bytes);
            if ap_ssid == ssid {
                target_ap_path = Some(path);
                break;
            }
        }

        let ap_path = target_ap_path.ok_or_else(|| {
            RdeError::NotFound(format!("Access point with SSID '{}' not found", ssid))
        })?;

        let mut connection_map = HashMap::new();

        let mut connection_setting = HashMap::new();
        connection_setting.insert(
            "id".to_string(),
            zbus::zvariant::Value::from(ssid.to_string()),
        );
        connection_setting.insert(
            "type".to_string(),
            zbus::zvariant::Value::from("802-11-wireless".to_string()),
        );
        connection_map.insert("connection".to_string(), connection_setting);

        let mut wireless_setting = HashMap::new();
        wireless_setting.insert(
            "ssid".to_string(),
            zbus::zvariant::Value::from(ssid.as_bytes().to_vec()),
        );
        wireless_setting.insert(
            "mode".to_string(),
            zbus::zvariant::Value::from("infrastructure".to_string()),
        );
        connection_map.insert("802-11-wireless".to_string(), wireless_setting);

        if let Some(pwd) = password {
            let mut security_setting = HashMap::new();
            security_setting.insert(
                "key-mgmt".to_string(),
                zbus::zvariant::Value::from("wpa-psk".to_string()),
            );
            security_setting.insert(
                "psk".to_string(),
                zbus::zvariant::Value::from(pwd.to_string()),
            );
            connection_map.insert("802-11-wireless-security".to_string(), security_setting);
        }

        self.nm_proxy
            .add_and_activate_connection(connection_map, device_path.clone(), ap_path)
            .await
            .map_err(RdeError::Dbus)?;

        Ok(())
    }

    /// Disconnects from the current Wi-Fi network.
    pub async fn disconnect(&self) -> RdeResult<()> {
        let device = self
            .current_device
            .as_ref()
            .ok_or_else(|| RdeError::ConfigNotFound("No Wi-Fi device active".to_string()))?;

        let active_connection = device.active_connection().await.map_err(RdeError::Dbus)?;

        if active_connection.as_str() == "/" {
            return Ok(());
        }

        self.nm_proxy
            .deactivate_connection(active_connection)
            .await
            .map_err(RdeError::Dbus)?;
        Ok(())
    }

    /// Deletes the saved connection profile for the given SSID.
    pub async fn forget_network(&self, ssid: &str) -> RdeResult<()> {
        let connection = &self.connection;
        let settings_proxy = SettingsProxy::new(connection)
            .await
            .map_err(RdeError::Dbus)?;

        let connection_paths = settings_proxy
            .list_connections()
            .await
            .map_err(RdeError::Dbus)?;

        for path in connection_paths {
            let conn_settings = match ConnectionSettingsProxy::new(connection, path).await {
                Ok(proxy) => proxy,
                Err(_) => continue,
            };

            let settings = match conn_settings.get_settings().await {
                Ok(s) => s,
                Err(_) => continue,
            };

            if let Some(wireless) = settings.get("802-11-wireless") {
                if let Some(ssid_val) = wireless.get("ssid") {
                    if let Ok(ssid_bytes) = <Vec<u8>>::try_from(ssid_val.clone()) {
                        let ap_ssid = String::from_utf8_lossy(&ssid_bytes);
                        if ap_ssid == ssid {
                            conn_settings.delete().await.map_err(RdeError::Dbus)?;
                            return Ok(());
                        }
                    }
                }
            }
        }

        Err(RdeError::NotFound(format!(
            "Saved profile for SSID '{}' not found",
            ssid
        )))
    }
}

/// Helper function to determine the SecurityType based on NetworkManager access point flags.
/// For more information, [See enum NM80211ApSecurityFlags](https://networkmanager.dev/docs/api/latest/nm-dbus-types.html#NM80211ApSecurityFlags)
fn determine_security_type(
    flags: u32,
    wpa_flags: u32,
    rsn_flags: u32,
) -> crate::domain::models::SecurityType {
    if (flags & 0x1) == 0 {
        return crate::domain::models::SecurityType::Open;
    }

    if (rsn_flags & 0x400) != 0 {
        return crate::domain::models::SecurityType::Wpa3;
    }
    if rsn_flags != 0 {
        return crate::domain::models::SecurityType::Wpa2;
    }

    if wpa_flags != 0 {
        return crate::domain::models::SecurityType::Wpa;
    }

    crate::domain::models::SecurityType::Unknown
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::dbus::mock::{MockDeviceProxy, MockNetworkManagerProxy};
    use zbus::zvariant::OwnedObjectPath;

    #[tokio::test]
    async fn test_wifi_backend_init_finds_wifi_device() {
        // 1. Create the mock NetworkManager proxy
        let mut mock_nm = MockNetworkManagerProxy::default();
        let dev_path =
            OwnedObjectPath::try_from("/org/freedesktop/NetworkManager/Devices/3").unwrap();
        let dev_path_clone = dev_path.clone();

        // 2. Setup expectation: get_all_devices should return our dummy device path
        mock_nm
            .expect_get_all_devices()
            .times(1)
            .returning(move || Ok(vec![dev_path_clone.clone()]));

        // 3. Setup static constructor mock context for DeviceProxy::new.
        // When DeviceProxy::new is called for our dummy path, return a mocked DeviceProxy
        // that asserts device type 2 (Wi-Fi).
        let ctx = MockDeviceProxy::new_context();
        ctx.expect().times(1).returning(|_, _path| {
            let mut mock_dev = MockDeviceProxy::default();
            mock_dev.expect_device_type().times(1).returning(|| Ok(2)); // Return 2 (NM_DEVICE_TYPE_WIFI)
            Ok(mock_dev)
        });

        // 4. Construct a self-contained connection using a UnixStream socket pair and dummy GUID.
        // This allows us to pass a valid zbus::Connection object to the backend constructor
        // without attempting any actual D-Bus handshake authentication or connecting to a system daemon.
        let (stream, _) = tokio::net::UnixStream::pair().unwrap();
        let guid = zbus::Guid::from_static_str("1234567890abcdef1234567890abcdef").unwrap();
        let connection = zbus::connection::Builder::authenticated_socket(stream, guid)
            .unwrap()
            .build()
            .await
            .unwrap();

        // 5. Instantiate the WifiBackend by injecting our mocked NetworkManagerProxy
        let mut backend = WifiBackend {
            connection,
            nm_proxy: mock_nm,
            devices: None,
            current_device: None,
            current_device_path: None,
            last_scaned_at: Utc::now(),
        };

        // 6. Run the scan_wifi_device function under test and assert the active Wi-Fi device was successfully cached
        let res = backend.scan_wifi_device().await;
        assert!(
            res.is_ok(),
            "backend.scan_wifi_device() should succeed with mock inputs"
        );
        assert!(
            backend.current_device.is_some(),
            "WifiBackend should detect and cache the mocked Wi-Fi device"
        );
        assert!(
            backend.current_device_path.is_some(),
            "WifiBackend should detect and cache the mocked Wi-Fi device path"
        );
    }
}
