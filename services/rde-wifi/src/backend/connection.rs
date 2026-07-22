//! # Wi-Fi Connection Management Backend Module
//!
//! This module implements connection-level operations for the `WifiBackend` struct.
//! It interfaces with NetworkManager's D-Bus Settings and Wireless AccessPoint services to:
//! - Retrieve saved Wi-Fi connection profiles from NetworkManager storage.
//! - Inspect security features (WPA/WPA2/WPA3/Open) for individual access points.
//! - Discover and rank available Wi-Fi access points by signal strength.
//! - Query details of the currently active Wi-Fi connection.
//! - Connect to open or passphrase-protected Wi-Fi networks via dynamic NetworkManager configuration maps.
//! - Disconnect active wireless sessions.
//! - Delete (forget) saved Wi-Fi connection profiles.

use rde_core::errors::{RdeError, RdeResult};
use std::collections::HashMap;

use super::{WifiBackend, determine_security_type};
use crate::infra::dbus::{AccessPointProxy, ConnectionSettingsProxy, SettingsProxy};

impl WifiBackend {
    /// Retrieves a list of all saved Wi-Fi network SSIDs stored by NetworkManager.
    ///
    /// This method queries NetworkManager's central `SettingsProxy` service (`/org/freedesktop/NetworkManager/Settings`)
    /// to enumerate all saved connection object paths, parses their underlying D-Bus settings dictionary
    /// for `802-11-wireless` network profiles, and extracts their SSID strings.
    ///
    /// # Returns
    /// - `Ok(Vec<String>)` containing the names (SSIDs) of all configured saved networks.
    /// - If NetworkManager settings services are unavailable, it logs a warning and returns an empty list gracefully.
    ///
    /// # Errors
    /// Returns `RdeResult::Ok` with available saved SSIDs; non-fatal failures log warnings.
    pub async fn get_saved_networks(&self) -> RdeResult<Vec<String>> {
        let connection = &self.connection;

        // Step 1: Connect to NetworkManager's Settings proxy service
        let settings_proxy = match SettingsProxy::new(connection).await {
            Ok(proxy) => proxy,
            Err(e) => {
                tracing::warn!("Failed to create SettingsProxy: {}", e);
                return Ok(Vec::new());
            }
        };

        // Step 2: Query object paths for all saved connections stored in NetworkManager
        let connection_paths = match settings_proxy.list_connections().await {
            Ok(paths) => paths,
            Err(e) => {
                tracing::warn!("Failed to list connections from NetworkManager: {}", e);
                return Ok(Vec::new());
            }
        };

        let mut saved = Vec::new();

        // Step 3: Inspect each connection object path to extract wireless SSID details
        for path in connection_paths {
            let conn_settings = match ConnectionSettingsProxy::new(connection, path).await {
                Ok(proxy) => proxy,
                Err(e) => {
                    tracing::warn!("Failed to create ConnectionSettingsProxy for path: {}", e);
                    continue;
                }
            };

            // Query the full nested settings map for this specific connection profile
            let settings = match conn_settings.get_settings().await {
                Ok(s) => s,
                Err(e) => {
                    tracing::warn!("Failed to get settings for connection: {}", e);
                    continue;
                }
            };

            // Parse the "802-11-wireless" dictionary block to extract the SSID byte array
            if let Some(wireless) = settings.get("802-11-wireless") {
                if let Some(ssid_val) = wireless.get("ssid") {
                    if let Ok(ssid_bytes) = <Vec<u8>>::try_from(ssid_val.clone()) {
                        // NetworkManager stores SSIDs as raw byte arrays (IEEE 802.11 spec allows arbitrary bytes).
                        // We decode using lossy UTF-8 conversion to support non-ASCII SSIDs safely.
                        let ap_ssid = String::from_utf8_lossy(&ssid_bytes);
                        saved.push(ap_ssid.into_owned());
                    }
                }
            }
        }

        Ok(saved)
    }

    /// Determines the security standard (e.g. `Open`, `Wpa2`, `Wpa3`) of a visible access point by SSID.
    ///
    /// # Parameters
    /// - `ssid`: The SSID name of the target Wi-Fi access point.
    ///
    /// # Returns
    /// - `Ok(String)` representing the stringified `SecurityType` variant (e.g. `"Wpa2"`).
    /// - `Err(RdeError::NotFound)` if no visible access point matches the specified SSID.
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` on communication error or `RdeError::NotFound` if SSID is not in range.
    pub async fn get_security_type(&self, ssid: &str) -> RdeResult<String> {
        // Obtain the wireless device proxy interface
        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;
        let connection = &self.connection;

        // Iterate through visible access points to locate the target SSID
        for path in ap_paths {
            let ap_proxy = match AccessPointProxy::new(connection, path.clone()).await {
                Ok(p) => p,
                Err(_) => continue,
            };

            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
            let ap_ssid = String::from_utf8_lossy(&ssid_bytes);

            if ap_ssid == ssid {
                // Query NetworkManager security flags for WPA, RSN (WPA2/WPA3), and standard capability flags
                let flags = ap_proxy.flags().await.unwrap_or_default();
                let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or_default();
                let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or_default();

                // Compute the high-level security standard enum
                let security = determine_security_type(flags, wpa_flags, rsn_flags);
                return Ok(format!("{:?}", security));
            }
        }

        Err(RdeError::NotFound(format!(
            "Access point with SSID '{}' not found",
            ssid
        )))
    }

    /// Retrieves all visible Wi-Fi access points currently scanned by the active wireless hardware.
    ///
    /// The resulting list of access points is automatically sorted in descending order by signal strength percentage (100% highest).
    /// Hidden access points (empty SSIDs) are filtered out automatically.
    ///
    /// # Returns
    /// - `Ok(Vec<AccessPointInfo>)` containing detailed information for each in-range access point.
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` if D-Bus communication with NetworkManager fails or if no Wi-Fi interface is active.
    pub async fn get_available_networks(
        &self,
    ) -> RdeResult<Vec<crate::domain::models::AccessPointInfo>> {
        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;

        let mut aps = Vec::new();
        let connection = &self.connection;

        // Query the D-Bus object path of the currently active/connected access point (if any)
        let active_ap_path = wireless.active_access_point().await.ok();

        for path in ap_paths {
            let ap_proxy = match AccessPointProxy::new(connection, path.clone()).await {
                Ok(proxy) => proxy,
                Err(e) => {
                    tracing::warn!("Failed to create AccessPoint proxy: {}", e);
                    continue;
                }
            };

            // Retrieve hardware address, frequency (MHz), signal strength (0-100), and raw SSID bytes
            let mac_address = ap_proxy.hw_address().await.unwrap_or_default();
            let frequency = ap_proxy.frequency().await.unwrap_or_default();
            let strength = ap_proxy.strength().await.unwrap_or_default();
            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
            let ssid = String::from_utf8_lossy(&ssid_bytes).into_owned();

            // Ignore hidden access points (empty SSID name)
            if ssid.is_empty() {
                continue;
            }

            // Read AP security capability flags and classify security protocol
            let flags = ap_proxy.flags().await.unwrap_or_default();
            let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or_default();
            let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or_default();
            let security = determine_security_type(flags, wpa_flags, rsn_flags);

            // Check if this access point path matches the active connection path
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

        // Sort access points by signal strength in descending order (strongest signals first)
        aps.sort_by_key(|b| std::cmp::Reverse(b.strength));
        Ok(aps)
    }

    /// Gets details of the currently active Wi-Fi connection.
    ///
    /// # Returns
    /// - `Ok(Some(AccessPointInfo))` if currently connected to a Wi-Fi access point.
    /// - `Ok(None)` if the wireless interface is disconnected (NetworkManager reports `"/"` object path).
    ///
    /// # Errors
    /// Returns `RdeError::Dbus` if querying NetworkManager fails.
    pub async fn get_current_connection(
        &self,
    ) -> RdeResult<Option<crate::domain::models::AccessPointInfo>> {
        let wireless = self.get_wireless_proxy().await?;
        let active_ap_path = wireless
            .active_access_point()
            .await
            .map_err(RdeError::Dbus)?;

        // NetworkManager returns "/" object path when no access point is connected
        if active_ap_path.as_str() == "/" {
            return Ok(None);
        }

        let connection = &self.connection;
        let ap_proxy = AccessPointProxy::new(connection, active_ap_path.clone())
            .await
            .map_err(RdeError::Dbus)?;

        // Gather metrics for active connection
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

    /// Connects to a Wi-Fi network matching the given SSID, creating a new NetworkManager connection profile if necessary.
    ///
    /// # Parameters
    /// - `ssid`: Target Wi-Fi SSID name.
    /// - `password`: Optional WPA/WPA2/WPA3 pre-shared key (passphrase). Pass `None` for open networks.
    ///
    /// # Process
    /// 1. Finds the access point D-Bus object path corresponding to `ssid`.
    /// 2. Constructs a NetworkManager setting dictionary structure (`HashMap<String, HashMap<String, Value>>`) containing:
    ///    - `"connection"`: setting ID (`ssid`) and connection type (`"802-11-wireless"`).
    ///    - `"802-11-wireless"`: SSID byte array and mode (`"infrastructure"`).
    ///    - `"802-11-wireless-security"`: security key management (`"wpa-psk"`) and PSK passphrase if `password` is provided.
    /// 3. Invokes NetworkManager's `AddAndActivateConnection` D-Bus method to initiate connection.
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if no active Wi-Fi device is present, `RdeError::NotFound` if target SSID is not in range,
    /// or `RdeError::Dbus` on NetworkManager activation errors.
    pub async fn connect_to_network(&self, ssid: &str, password: Option<&str>) -> RdeResult<()> {
        // Step 1: Ensure active Wi-Fi device path is available
        let device_path = self
            .current_device_path
            .as_ref()
            .ok_or_else(|| RdeError::ConfigNotFound("No Wi-Fi device active".to_string()))?;

        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;
        let connection = &self.connection;

        // Step 2: Locate target access point object path matching requested SSID
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

        // Step 3: Build NetworkManager D-Bus setting configuration dictionary
        let mut connection_map = HashMap::new();

        // Sub-dictionary 1: General connection settings
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

        // Sub-dictionary 2: 802.11 Wireless hardware settings
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

        // Sub-dictionary 3: Wireless security credentials (if password provided)
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

        // Step 4: Dispatch AddAndActivateConnection call to NetworkManager
        self.nm_proxy
            .add_and_activate_connection(connection_map, device_path.clone(), ap_path)
            .await
            .map_err(RdeError::Dbus)?;

        Ok(())
    }

    /// Disconnects the active Wi-Fi connection session on the active network interface.
    ///
    /// # Errors
    /// Returns `RdeError::ConfigNotFound` if no active Wi-Fi device is present, or `RdeError::Dbus` if NetworkManager deactivation fails.
    pub async fn disconnect(&self) -> RdeResult<()> {
        let device = self
            .current_device
            .as_ref()
            .ok_or_else(|| RdeError::ConfigNotFound("No Wi-Fi device active".to_string()))?;

        // Query active connection object path from device
        let active_connection = device.active_connection().await.map_err(RdeError::Dbus)?;

        // Path "/" indicates device is currently idle / disconnected
        if active_connection.as_str() == "/" {
            return Ok(());
        }

        // Deactivate connection via NetworkManager proxy
        self.nm_proxy
            .deactivate_connection(active_connection)
            .await
            .map_err(RdeError::Dbus)?;
        Ok(())
    }

    /// Deletes the saved NetworkManager connection profile matching the specified SSID.
    ///
    /// # Parameters
    /// - `ssid`: Target network profile SSID to delete.
    ///
    /// # Errors
    /// Returns `RdeError::NotFound` if no saved profile matching `ssid` exists, or `RdeError::Dbus` on deletion error.
    pub async fn forget_network(&self, ssid: &str) -> RdeResult<()> {
        let connection = &self.connection;
        let settings_proxy = SettingsProxy::new(connection)
            .await
            .map_err(RdeError::Dbus)?;

        let connection_paths = settings_proxy
            .list_connections()
            .await
            .map_err(RdeError::Dbus)?;

        // Search saved connections for matching SSID
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
                            // Call Delete on NetworkManager connection settings object
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
