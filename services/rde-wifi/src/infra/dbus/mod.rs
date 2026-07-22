//! # D-Bus Infrastructure Proxies & Mocks
//!
//! Conditionally exports real `zbus` D-Bus proxies for production builds,
//! or `mockall` mock proxy structs during testing.

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
