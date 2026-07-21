use std::collections::HashMap;
use zbus::{
    Result, proxy,
    zvariant::{OwnedObjectPath, OwnedValue, Value},
};

// ===== NetworkManager Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
pub trait NetworkManager {
    /// Get all network devices
    fn get_all_devices(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Get all saved connections
    async fn list_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;

    /// Get device by network interface name (e.g., "wlan0")
    fn get_device_by_ip_iface(&self, iface: &str) -> Result<OwnedObjectPath>;

    /// Check if WiFi is enabled
    #[zbus(property)]
    fn wireless_enabled(&self) -> Result<bool>;

    /// Enable/disable WiFi
    #[zbus(property)]
    fn set_wireless_enabled(&self, enabled: bool) -> Result<()>;

    /// Check if networking is enabled
    #[zbus(property)]
    fn networking_enabled(&self) -> Result<bool>;

    /// Activate a connection
    fn activate_connection(
        &self,
        connection: &zbus::zvariant::ObjectPath<'_>,
        device: &zbus::zvariant::ObjectPath<'_>,
        specific_object: &zbus::zvariant::ObjectPath<'_>,
    ) -> Result<OwnedObjectPath>;

    /// Add and activate a new connection (e.g. for connecting to a new AP)
    fn add_and_activate_connection(
        &self,
        connection: HashMap<String, HashMap<String, Value<'_>>>,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> Result<(OwnedObjectPath, OwnedObjectPath)>;

    /// Deactivate an active connection
    fn deactivate_connection(&self, active_connection: OwnedObjectPath) -> Result<()>;
}

// ===== Device Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Device"
)]
pub trait Device {
    /// Get the type of device (e.g. 1 = Ethernet, 2 = WiFi)
    #[zbus(property)]
    fn device_type(&self) -> Result<u32>;

    /// Operating state of the device
    #[zbus(property)]
    fn state(&self) -> Result<u32>;

    /// Interface name (e.g. "wlan0")
    #[zbus(property)]
    fn interface(&self) -> Result<String>;

    /// Active connection path, if any
    #[zbus(property)]
    fn active_connection(&self) -> Result<OwnedObjectPath>;
}

// ===== Wireless Device Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Device.Wireless"
)]
pub trait Wireless {
    /// Request a scan for access points
    fn request_scan(&self, options: HashMap<&str, Value<'_>>) -> Result<()>;

    /// Get all access points
    fn get_access_points(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Get all access points, including expired ones
    fn get_all_access_points(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Active access point property
    #[zbus(property)]
    fn active_access_point(&self) -> Result<OwnedObjectPath>;

    /// Wireless hardware address (MAC)
    #[zbus(property)]
    fn hw_address(&self) -> Result<String>;
}

// ===== AccessPoint Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.AccessPoint"
)]
pub trait AccessPoint {
    /// Access Point flags
    #[zbus(property)]
    fn flags(&self) -> Result<u32>;

    /// WPA security flags
    #[zbus(property)]
    fn wpa_flags(&self) -> Result<u32>;

    /// RSN (WPA2/WPA3) security flags
    #[zbus(property)]
    fn rsn_flags(&self) -> Result<u32>;

    /// SSID of the AP
    #[zbus(property)]
    fn ssid(&self) -> Result<Vec<u8>>;

    /// Signal strength (0-100)
    #[zbus(property)]
    fn strength(&self) -> Result<u8>;

    /// Frequency in MHz
    #[zbus(property)]
    fn frequency(&self) -> Result<u32>;

    /// Hardware address (BSSID)
    #[zbus(property)]
    fn hw_address(&self) -> Result<String>;
}

// ===== Settings Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/Settings",
    interface = "org.freedesktop.NetworkManager.Settings"
)]
pub trait Settings {
    /// List all saved connections
    fn list_connections(&self) -> Result<Vec<OwnedObjectPath>>;
}

// ===== ConnectionSettings Proxy =====
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Settings.Connection"
)]
pub trait ConnectionSettings {
    /// Get connection settings
    fn get_settings(&self) -> Result<HashMap<String, HashMap<String, OwnedValue>>>;

    /// Delete connection profile
    fn delete(&self) -> Result<()>;
}
