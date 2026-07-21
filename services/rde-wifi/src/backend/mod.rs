use chrono::{DateTime, Utc};
use rde_core::errors::{RdeError, RdeResult};
use zbus::Connection;
use zbus::zvariant::OwnedObjectPath;

use crate::infra::dbus::NetworkManagerProxy;

pub(crate) mod connection;
pub(crate) mod device;

#[cfg(test)]
mod tests;

/// Backend service for managing Wi-Fi state and NetworkManager interactions.
///
/// It establishes and maintains a system D-Bus connection to the `org.freedesktop.NetworkManager`
/// service and caches proxy objects for communication.
#[allow(dead_code)]
pub struct WifiBackend {
    /// The core system D-Bus connection.
    pub(crate) connection: Connection,
    /// Proxy object for the main NetworkManager D-Bus interface.
    pub(crate) nm_proxy: NetworkManagerProxy<'static>,

    /// Cache of device proxies currently available on the system.
    pub(crate) devices: Option<Vec<crate::infra::dbus::DeviceProxy<'static>>>,
    /// Cache of the currently active Wi-Fi device proxy, if found.
    pub(crate) current_device: Option<crate::infra::dbus::DeviceProxy<'static>>,
    /// Cache of the active Wi-Fi device D-Bus object path.
    pub(crate) current_device_path: Option<OwnedObjectPath>,

    /// Timestamp indicating when the last network scan or query was performed.
    pub(crate) last_scaned_at: DateTime<Utc>,
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
        me.scan_wifi_devices().await?;

        Ok(me)
    }
}

/// Helper function to determine the SecurityType based on NetworkManager access point flags.
/// For more information, [See enum NM80211ApSecurityFlags](https://networkmanager.dev/docs/api/latest/nm-dbus-types.html#NM80211ApSecurityFlags)
pub(crate) fn determine_security_type(
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
