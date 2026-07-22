//! # Wi-Fi Backend Engine Module
//!
//! The backend module manages hardware interface discovery, device state tracking,
//! D-Bus connection proxies, and Wi-Fi security flag parsing.

use chrono::{DateTime, Utc};
use rde_core::errors::{RdeError, RdeResult};
use zbus::Connection;
use zbus::zvariant::OwnedObjectPath;

use crate::infra::dbus::NetworkManagerProxy;

pub(crate) mod connection;
pub(crate) mod device;

#[cfg(test)]
mod tests;

/// Core backend engine for managing Wi-Fi state and NetworkManager interactions.
///
/// It establishes and maintains a system D-Bus connection to the `org.freedesktop.NetworkManager`
/// service and caches proxy objects for communication with system Wi-Fi interfaces.
#[allow(dead_code)]
pub struct WifiBackend {
    /// The system D-Bus bus connection used for IPC with NetworkManager.
    pub(crate) connection: Connection,

    /// Main NetworkManager D-Bus service proxy (`/org/freedesktop/NetworkManager`).
    pub(crate) nm_proxy: NetworkManagerProxy<'static>,

    /// Cache of device proxies currently available on the system.
    pub(crate) devices: Option<Vec<crate::infra::dbus::DeviceProxy<'static>>>,

    /// Cached proxy object for the active Wi-Fi hardware device interface.
    pub(crate) current_device: Option<crate::infra::dbus::DeviceProxy<'static>>,

    /// Cached D-Bus object path for the active Wi-Fi interface (e.g., `/org/freedesktop/NetworkManager/Devices/2`).
    pub(crate) current_device_path: Option<OwnedObjectPath>,

    /// Timestamp indicating when the last network scan or device query was performed.
    pub(crate) last_scaned_at: DateTime<Utc>,
}

impl WifiBackend {
    /// Constructs a new `WifiBackend` instance by establishing a connection
    /// to the Linux system D-Bus and initializing NetworkManager proxies.
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

        // Scan system network devices and select the active Wi-Fi interface
        me.scan_wifi_devices().await?;

        Ok(me)
    }
}

/// Helper function to convert NetworkManager 802.11 access point capability flags
/// into high-level `SecurityType` enums.
///
/// For more information on bitfield values, refer to the
/// [NetworkManager API Documentation for NM80211ApSecurityFlags](https://networkmanager.dev/docs/api/latest/nm-dbus-types.html#NM80211ApSecurityFlags).
///
/// # Logic
/// - Bit `0x1` missing in `flags` => `SecurityType::Open` (unencrypted network).
/// - Bit `0x400` set in `rsn_flags` => `SecurityType::Wpa3` (SAE / WPA3 Personal).
/// - Non-zero `rsn_flags` => `SecurityType::Wpa2` (WPA2 RSN standard).
/// - Non-zero `wpa_flags` => `SecurityType::Wpa` (legacy WPA standard).
/// - Otherwise => `SecurityType::Unknown`.
pub(crate) fn determine_security_type(
    flags: u32,
    wpa_flags: u32,
    rsn_flags: u32,
) -> crate::domain::models::SecurityType {
    // If privacy bit 0x1 is clear, the network is unencrypted (Open)
    if (flags & 0x1) == 0 {
        return crate::domain::models::SecurityType::Open;
    }

    // Check RSN (Robust Security Network / WPA2 / WPA3) flags
    if (rsn_flags & 0x400) != 0 {
        return crate::domain::models::SecurityType::Wpa3;
    }
    if rsn_flags != 0 {
        return crate::domain::models::SecurityType::Wpa2;
    }

    // Check legacy WPA flags
    if wpa_flags != 0 {
        return crate::domain::models::SecurityType::Wpa;
    }

    crate::domain::models::SecurityType::Unknown
}
