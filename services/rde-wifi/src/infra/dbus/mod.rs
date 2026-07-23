//! # D-Bus Infrastructure Proxies & Mocks
//!
//! Conditionally exports real `zbus` D-Bus proxies for production builds,
//! or `mockall` mock proxy structs during testing.
//!
//! ## Features
//! - Conditional compilation export (`cfg(not(test))` vs `cfg(test)`)
//! - Unified interface abstraction for D-Bus communication
//!
//! ## Related
//! - [`crate::infra::dbus::nm_proxy`]
//! - [`crate::infra::dbus::mock`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

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
