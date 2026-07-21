use rde_core::errors::{RdeError, RdeResult};
use std::collections::HashMap;

use super::{WifiBackend, determine_security_type};
use crate::infra::dbus::{AccessPointProxy, ConnectionSettingsProxy, SettingsProxy};

impl WifiBackend {
    /// Gets a list of all saved Wi-Fi connection SSIDs.
    pub async fn get_saved_networks(&self) -> RdeResult<Vec<String>> {
        let connection = &self.connection;
        let settings_proxy = SettingsProxy::new(connection)
            .await
            .map_err(RdeError::Dbus)?;

        let connection_paths = settings_proxy
            .list_connections()
            .await
            .map_err(RdeError::Dbus)?;

        let mut saved = Vec::new();
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
                        saved.push(ap_ssid.into_owned());
                    }
                }
            }
        }

        Ok(saved)
    }

    /// Gets the security type of the access point with the given SSID.
    pub async fn get_security_type(&self, ssid: &str) -> RdeResult<String> {
        let wireless = self.get_wireless_proxy().await?;
        let ap_paths = wireless.get_access_points().await.map_err(RdeError::Dbus)?;
        let connection = &self.connection;

        for path in ap_paths {
            let ap_proxy = match AccessPointProxy::new(connection, path.clone()).await {
                Ok(p) => p,
                Err(_) => continue,
            };
            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
            let ap_ssid = String::from_utf8_lossy(&ssid_bytes);
            if ap_ssid == ssid {
                let flags = ap_proxy.flags().await.unwrap_or_default();
                let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or_default();
                let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or_default();
                let security = determine_security_type(flags, wpa_flags, rsn_flags);
                return Ok(format!("{:?}", security));
            }
        }

        Err(RdeError::NotFound(format!(
            "Access point with SSID '{}' not found",
            ssid
        )))
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
