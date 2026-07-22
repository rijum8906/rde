//! # Mock NetworkManager D-Bus Proxies
//!
//! Provides unit test mocks generated using `mockall::mock!` matching NetworkManager D-Bus proxy interfaces.

use std::collections::HashMap;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};

mockall::mock! {
    /// Mock representation of `NetworkManagerProxy`.
    pub NetworkManagerProxy<'a> {
        pub async fn new(connection: &zbus::Connection) -> zbus::Result<MockNetworkManagerProxy<'static>>;
        pub async fn get_all_devices(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
        pub async fn get_device_by_ip_iface(&self, iface: &str) -> zbus::Result<OwnedObjectPath>;
        pub async fn wireless_enabled(&self) -> zbus::Result<bool>;
        pub async fn set_wireless_enabled(&self, enabled: bool) -> zbus::Result<()>;
        pub async fn networking_enabled(&self) -> zbus::Result<bool>;
        pub async fn activate_connection(
            &self,
            connection: &zbus::zvariant::ObjectPath<'static>,
            device: &zbus::zvariant::ObjectPath<'static>,
            specific_object: &zbus::zvariant::ObjectPath<'static>,
        ) -> zbus::Result<OwnedObjectPath>;
        pub async fn add_and_activate_connection(
            &self,
            connection: HashMap<String, HashMap<String, Value<'static>>>,
            device: OwnedObjectPath,
            specific_object: OwnedObjectPath,
        ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;
        pub async fn deactivate_connection(&self, active_connection: OwnedObjectPath) -> zbus::Result<()>;
    }
}

pub type NetworkManagerProxy<'a> = MockNetworkManagerProxy<'a>;

mockall::mock! {
    /// Mock representation of `DeviceProxy`.
    pub DeviceProxy<'a> {
        pub async fn new(connection: &zbus::Connection, path: OwnedObjectPath) -> zbus::Result<MockDeviceProxy<'static>>;
        pub async fn device_type(&self) -> zbus::Result<u32>;
        pub async fn state(&self) -> zbus::Result<u32>;
        pub async fn interface(&self) -> zbus::Result<String>;
        pub async fn active_connection(&self) -> zbus::Result<OwnedObjectPath>;
    }
}

pub type DeviceProxy<'a> = MockDeviceProxy<'a>;

mockall::mock! {
    /// Mock representation of `WirelessProxy`.
    pub WirelessProxy<'a> {
        pub async fn new(connection: &zbus::Connection, path: OwnedObjectPath) -> zbus::Result<MockWirelessProxy<'static>>;
        pub async fn request_scan(&self, options: HashMap<&'static str, Value<'static>>) -> zbus::Result<()>;
        pub async fn get_access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
        pub async fn get_all_access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
        pub async fn active_access_point(&self) -> zbus::Result<OwnedObjectPath>;
        pub async fn hw_address(&self) -> zbus::Result<String>;
    }
}

pub type WirelessProxy<'a> = MockWirelessProxy<'a>;

mockall::mock! {
    /// Mock representation of `AccessPointProxy`.
    pub AccessPointProxy<'a> {
        pub async fn new(connection: &zbus::Connection, path: OwnedObjectPath) -> zbus::Result<MockAccessPointProxy<'static>>;
        pub async fn flags(&self) -> zbus::Result<u32>;
        pub async fn wpa_flags(&self) -> zbus::Result<u32>;
        pub async fn rsn_flags(&self) -> zbus::Result<u32>;
        pub async fn ssid(&self) -> zbus::Result<Vec<u8>>;
        pub async fn strength(&self) -> zbus::Result<u8>;
        pub async fn frequency(&self) -> zbus::Result<u32>;
        pub async fn hw_address(&self) -> zbus::Result<String>;
    }
}

pub type AccessPointProxy<'a> = MockAccessPointProxy<'a>;

mockall::mock! {
    /// Mock representation of `SettingsProxy`.
    pub SettingsProxy<'a> {
        pub async fn new(connection: &zbus::Connection) -> zbus::Result<MockSettingsProxy<'static>>;
        pub async fn list_connections(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
    }
}

pub type SettingsProxy<'a> = MockSettingsProxy<'a>;

mockall::mock! {
    /// Mock representation of `ConnectionSettingsProxy`.
    pub ConnectionSettingsProxy<'a> {
        pub async fn new(connection: &zbus::Connection, path: OwnedObjectPath) -> zbus::Result<MockConnectionSettingsProxy<'static>>;
        pub async fn get_settings(&self) -> zbus::Result<HashMap<String, HashMap<String, OwnedValue>>>;
        pub async fn delete(&self) -> zbus::Result<()>;
    }
}

pub type ConnectionSettingsProxy<'a> = MockConnectionSettingsProxy<'a>;
