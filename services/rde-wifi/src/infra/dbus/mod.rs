pub mod mock;
pub mod nm_proxy;

#[cfg(not(test))]
pub use nm_proxy::{
    AccessPointProxy, ConnectionSettingsProxy, DeviceProxy, NetworkManagerProxy, SettingsProxy,
    WirelessProxy,
};

#[cfg(test)]
pub use mock::{
    AccessPointProxy, ConnectionSettingsProxy, DeviceProxy, NetworkManagerProxy, SettingsProxy,
    WirelessProxy,
};
