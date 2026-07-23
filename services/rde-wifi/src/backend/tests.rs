//! # Unit Tests for Wi-Fi Backend Engine
//!
//! Isolated unit tests for `WifiBackend` methods, utilizing `mockall`
//! mocks for NetworkManager D-Bus proxies and Unix stream sockets for dummy D-Bus connections.
//!
//! ## Features
//! - Dummy authenticated `zbus::Connection` creation via Unix socket pairs
//! - Mock unit tests for device scanning, hardware selection, and connection logic
//! - Offline unit test coverage without system NetworkManager D-Bus requirement
//!
//! ## Related
//! - [`crate::backend::WifiBackend`]
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

use super::WifiBackend;
use crate::infra::dbus::mock::{
    MockConnectionSettingsProxy, MockDeviceProxy, MockNetworkManagerProxy, MockSettingsProxy,
    MockWirelessProxy,
};
use chrono::Utc;
use std::collections::HashMap;
use zbus::zvariant::OwnedObjectPath;

/// Constructs an authenticated dummy `zbus::Connection` backed by an in-memory Unix stream pair.
///
/// This avoids requiring a running D-Bus system daemon during unit testing.
async fn dummy_connection() -> zbus::Connection {
    let (stream, _) = tokio::net::UnixStream::pair().unwrap();
    let guid = zbus::Guid::from_static_str("1234567890abcdef1234567890abcdef").unwrap();
    zbus::connection::Builder::authenticated_socket(stream, guid)
        .unwrap()
        .build()
        .await
        .unwrap()
}

/// Tests that `WifiBackend::scan_wifi_devices()` correctly queries system devices
/// and caches the first Wi-Fi interface (DeviceType 2).
#[tokio::test]
async fn test_wifi_backend_init_finds_wifi_device() {
    // 1. Create the mock NetworkManager proxy
    let mut mock_nm = MockNetworkManagerProxy::default();
    let dev_path = OwnedObjectPath::try_from("/org/freedesktop/NetworkManager/Devices/3").unwrap();
    let dev_path_clone = dev_path.clone();

    // 2. Setup expectation: get_all_devices should return our dummy device path
    mock_nm
        .expect_get_all_devices()
        .times(1)
        .returning(move || Ok(vec![dev_path_clone.clone()]));

    // 3. Setup static constructor mock context for DeviceProxy::new.
    let ctx = MockDeviceProxy::new_context();
    ctx.expect().times(1).returning(|_, _path| {
        let mut mock_dev = MockDeviceProxy::default();
        mock_dev.expect_device_type().times(1).returning(|| Ok(2)); // Return 2 (NM_DEVICE_TYPE_WIFI)
        Ok(mock_dev)
    });

    // 4. Construct a self-contained connection
    let connection = dummy_connection().await;

    // 5. Instantiate the WifiBackend by injecting our mocked NetworkManagerProxy
    let mut backend = WifiBackend {
        connection,
        nm_proxy: mock_nm,
        devices: None,
        current_device: None,
        current_device_path: None,
        last_scaned_at: Utc::now(),
    };

    // 6. Run the scan_wifi_devices function under test
    let res = backend.scan_wifi_devices().await;
    assert!(
        res.is_ok(),
        "backend.scan_wifi_devices() should succeed with mock inputs"
    );
    assert!(
        backend.current_device.is_some(),
        "WifiBackend should detect and cache the mocked Wi-Fi device"
    );
    assert!(
        backend.current_device_path.is_some(),
        "WifiBackend should detect and cache the mocked Wi-Fi device path"
    );
}

/// Tests `set_wifi_enabled` and `is_wifi_enabled` by verifying D-Bus method call expectations.
#[tokio::test]
async fn test_wifi_backend_set_wifi_enabled() {
    let connection = dummy_connection().await;
    let mut mock_nm = MockNetworkManagerProxy::default();

    mock_nm
        .expect_set_wireless_enabled()
        .with(mockall::predicate::eq(true))
        .times(1)
        .returning(|_| Ok(()));

    mock_nm
        .expect_wireless_enabled()
        .times(1)
        .returning(|| Ok(true));

    let backend = WifiBackend {
        connection,
        nm_proxy: mock_nm,
        devices: None,
        current_device: None,
        current_device_path: None,
        last_scaned_at: Utc::now(),
    };

    assert!(backend.set_wifi_enabled(true).await.is_ok());
    let enabled = backend.is_wifi_enabled().await.unwrap();
    assert!(enabled);
}

/// Tests `get_saved_networks` by mocking NetworkManager Settings and ConnectionSettings proxies.
#[tokio::test]
async fn test_wifi_backend_get_saved_networks() {
    let connection = dummy_connection().await;
    let mock_nm = MockNetworkManagerProxy::default();

    let path = OwnedObjectPath::try_from("/org/freedesktop/NetworkManager/Settings/1").unwrap();
    let path_clone = path.clone();

    // Mock SettingsProxy::new
    let settings_ctx = MockSettingsProxy::new_context();
    settings_ctx.expect().times(1).returning(move |_| {
        let mut mock_settings = MockSettingsProxy::default();
        let path_clone = path_clone.clone();
        mock_settings
            .expect_list_connections()
            .times(1)
            .returning(move || Ok(vec![path_clone.clone()]));
        Ok(mock_settings)
    });

    // Mock ConnectionSettingsProxy::new
    let conn_settings_ctx = MockConnectionSettingsProxy::new_context();
    conn_settings_ctx
        .expect()
        .times(1)
        .returning(move |_, _path| {
            let mut mock_conn_settings = MockConnectionSettingsProxy::default();
            mock_conn_settings
                .expect_get_settings()
                .times(1)
                .returning(|| {
                    let mut settings = HashMap::new();
                    let mut wireless = HashMap::new();
                    wireless.insert(
                        "ssid".to_string(),
                        zbus::zvariant::OwnedValue::try_from(zbus::zvariant::Value::from(
                            b"MyTestSSID".to_vec(),
                        ))
                        .unwrap(),
                    );
                    settings.insert("802-11-wireless".to_string(), wireless);
                    Ok(settings)
                });
            Ok(mock_conn_settings)
        });

    let backend = WifiBackend {
        connection,
        nm_proxy: mock_nm,
        devices: None,
        current_device: None,
        current_device_path: None,
        last_scaned_at: Utc::now(),
    };

    let saved = backend.get_saved_networks().await.unwrap();
    assert_eq!(saved.len(), 1);
    assert_eq!(saved[0], "MyTestSSID");
}

/// Tests `request_scan` by mocking WirelessProxy's `request_scan` method call.
#[tokio::test]
async fn test_wifi_backend_request_scan() {
    let connection = dummy_connection().await;
    let mock_nm = MockNetworkManagerProxy::default();
    let dev_path = OwnedObjectPath::try_from("/org/freedesktop/NetworkManager/Devices/3").unwrap();

    // Mock WirelessProxy::new
    let wireless_ctx = MockWirelessProxy::new_context();
    wireless_ctx.expect().times(1).returning(|_, _path| {
        let mut mock_wireless = MockWirelessProxy::default();
        mock_wireless
            .expect_request_scan()
            .times(1)
            .returning(|_| Ok(()));
        Ok(mock_wireless)
    });

    let backend = WifiBackend {
        connection,
        nm_proxy: mock_nm,
        devices: None,
        current_device: None,
        current_device_path: Some(dev_path),
        last_scaned_at: Utc::now(),
    };

    assert!(backend.request_scan().await.is_ok());
}
