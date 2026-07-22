//! # NetworkManager D-Bus Proxy Declarations (`zbus`)
//!
//! Defines strongly-typed Rust traits mapped to NetworkManager's system D-Bus interfaces
//! (`org.freedesktop.NetworkManager.*`) using the `zbus::proxy` procedural macro.

use std::collections::HashMap;
use zbus::{
    Result, proxy,
    zvariant::{OwnedObjectPath, OwnedValue, Value},
};

// ===== NetworkManager Proxy =====
/// Proxy interface for the main NetworkManager D-Bus service (`org.freedesktop.NetworkManager`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
pub trait NetworkManager {
    /// Queries all network interface object paths registered with NetworkManager.
    fn get_all_devices(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Queries all saved connection object paths.
    async fn list_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;

    /// Queries the D-Bus object path of a device given its network interface name (e.g. `"wlan0"`).
    fn get_device_by_ip_iface(&self, iface: &str) -> Result<OwnedObjectPath>;

    /// Read-only property indicating if Wi-Fi wireless networking is enabled globally.
    #[zbus(property)]
    fn wireless_enabled(&self) -> Result<bool>;

    /// Property setter to enable or disable global Wi-Fi wireless networking.
    #[zbus(property)]
    fn set_wireless_enabled(&self, enabled: bool) -> Result<()>;

    /// Read-only property indicating if overall networking is enabled globally.
    #[zbus(property)]
    fn networking_enabled(&self) -> Result<bool>;

    /// Activates an existing saved connection on a specific device and access point.
    fn activate_connection(
        &self,
        connection: &zbus::zvariant::ObjectPath<'_>,
        device: &zbus::zvariant::ObjectPath<'_>,
        specific_object: &zbus::zvariant::ObjectPath<'_>,
    ) -> Result<OwnedObjectPath>;

    /// Adds a new connection profile dynamically and activates it on the specified device and access point.
    fn add_and_activate_connection(
        &self,
        connection: HashMap<String, HashMap<String, Value<'_>>>,
        device: OwnedObjectPath,
        specific_object: OwnedObjectPath,
    ) -> Result<(OwnedObjectPath, OwnedObjectPath)>;

    /// Deactivates an active connection by its active connection object path.
    fn deactivate_connection(&self, active_connection: OwnedObjectPath) -> Result<()>;
}

// ===== Device Proxy =====
/// Proxy interface for a generic NetworkManager device (`org.freedesktop.NetworkManager.Device`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Device"
)]
pub trait Device {
    /// Reads the hardware device type (1 = Ethernet, 2 = Wi-Fi, etc.).
    #[zbus(property)]
    fn device_type(&self) -> Result<u32>;

    /// Reads the operating state of the device (e.g. 100 = Activated).
    #[zbus(property)]
    fn state(&self) -> Result<u32>;

    /// Reads the Linux network interface identifier string (e.g., `"wlan0"`).
    #[zbus(property)]
    fn interface(&self) -> Result<String>;

    /// Reads the object path of the active connection associated with this device.
    #[zbus(property)]
    fn active_connection(&self) -> Result<OwnedObjectPath>;
}

// ===== Wireless Device Proxy =====
/// Proxy interface for a Wi-Fi wireless device (`org.freedesktop.NetworkManager.Device.Wireless`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Device.Wireless"
)]
pub trait Wireless {
    /// Triggers an asynchronous spectrum scan for access points.
    fn request_scan(&self, options: HashMap<&str, Value<'_>>) -> Result<()>;

    /// Returns object paths of currently visible access points.
    fn get_access_points(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Returns object paths of all access points, including expired ones.
    fn get_all_access_points(&self) -> Result<Vec<OwnedObjectPath>>;

    /// Property containing the object path of the currently connected access point.
    #[zbus(property)]
    fn active_access_point(&self) -> Result<OwnedObjectPath>;

    /// Reads the wireless MAC hardware address (BSSID).
    #[zbus(property)]
    fn hw_address(&self) -> Result<String>;
}

// ===== AccessPoint Proxy =====
/// Proxy interface for an individual Wi-Fi access point (`org.freedesktop.NetworkManager.AccessPoint`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.AccessPoint"
)]
pub trait AccessPoint {
    /// Reads general 802.11 access point capability flags.
    #[zbus(property)]
    fn flags(&self) -> Result<u32>;

    /// Reads WPA security capability flags.
    #[zbus(property)]
    fn wpa_flags(&self) -> Result<u32>;

    /// Reads RSN (WPA2/WPA3) security capability flags.
    #[zbus(property)]
    fn rsn_flags(&self) -> Result<u32>;

    /// Reads raw SSID byte array.
    #[zbus(property)]
    fn ssid(&self) -> Result<Vec<u8>>;

    /// Reads signal strength percentage (0-100).
    #[zbus(property)]
    fn strength(&self) -> Result<u8>;

    /// Reads operating frequency in MHz (e.g., 2412 MHz or 5180 MHz).
    #[zbus(property)]
    fn frequency(&self) -> Result<u32>;

    /// Reads hardware BSSID address string.
    #[zbus(property)]
    fn hw_address(&self) -> Result<String>;
}

// ===== Settings Proxy =====
/// Proxy interface for NetworkManager Settings manager (`org.freedesktop.NetworkManager.Settings`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager/Settings",
    interface = "org.freedesktop.NetworkManager.Settings"
)]
pub trait Settings {
    /// Lists all saved connection object paths.
    fn list_connections(&self) -> Result<Vec<OwnedObjectPath>>;
}

// ===== ConnectionSettings Proxy =====
/// Proxy interface for an individual connection profile (`org.freedesktop.NetworkManager.Settings.Connection`).
#[proxy(
    default_service = "org.freedesktop.NetworkManager",
    interface = "org.freedesktop.NetworkManager.Settings.Connection"
)]
pub trait ConnectionSettings {
    /// Retrieves the nested dictionary of settings key-value pairs defining this connection profile.
    fn get_settings(&self) -> Result<HashMap<String, HashMap<String, OwnedValue>>>;

    /// Deletes this connection profile permanently from NetworkManager storage.
    fn delete(&self) -> Result<()>;
}
