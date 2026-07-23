//! # Wi-Fi Domain Data Models
//!
//! Structs and enums representing Wi-Fi access points, encryption standards,
//! asynchronous backend events, and connection lifecycle states.
//!
//! ## Features
//! - `AccessPointInfo` struct with Serde and `zbus::zvariant` serialization support
//! - `SecurityType` enum representing Open, WEP, WPA, WPA2, WPA3, and Enterprise protocols
//! - `WifiState` and `WifiEvent` definitions for reactive UI binding
//!
//! ## Related
//! - [`crate::backend::WifiBackend`]
//! - [`crate::dbus::iface::WifiInterface`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use serde::{Deserialize, Serialize};
use zbus::zvariant::{Type, Value};

/// Comprehensive metadata describing a scanned Wi-Fi access point.
#[derive(Debug, Clone, Serialize, Deserialize, Type, Value)]
pub struct AccessPointInfo {
    /// D-Bus object path of the access point (e.g., `/org/freedesktop/NetworkManager/AccessPoint/42`).
    pub path: String,
    /// Service Set Identifier (network name).
    pub ssid: String,
    /// Signal strength percentage (0 - 100).
    pub strength: u8,
    /// Encryption/security protocol supported by the access point.
    pub security: SecurityType,
    /// Hardware BSSID MAC address (e.g., `"00:11:22:33:44:55"`).
    pub mac_address: String,
    /// Operating frequency in MHz (e.g., `2412` for 2.4GHz channel 1, `5180` for 5GHz channel 36).
    pub frequency: u32,
    /// Whether this access point is currently connected to the active wireless device.
    pub is_connected: bool,
    /// Whether a saved connection profile exists for this SSID in NetworkManager.
    pub is_saved: bool,
}

/// Supported Wi-Fi security / encryption standards.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Type, Value)]
pub enum SecurityType {
    /// Open network (no encryption/passphrase required).
    Open,
    /// Legacy WEP security.
    Wep,
    /// First-generation WPA security.
    Wpa,
    /// WPA2 Personal (RSN with CCMP/TKIP).
    Wpa2,
    /// WPA3 Personal (SAE).
    Wpa3,
    /// WPA/WPA2/WPA3 Enterprise (802.1X EAP authentication).
    Enterprise,
    /// Unclassified or unknown security scheme.
    Unknown,
}

/// Asynchronous events emitted by the Wi-Fi backend engine during operation.
#[derive(Debug, Clone)]
pub enum WifiEvent {
    /// Spectrum scan initiated.
    ScanStarted,
    /// Spectrum scan completed.
    ScanCompleted,
    /// New access point detected in range (AP object path).
    AccessPointAdded(String),
    /// Access point lost or went out of range (AP object path).
    AccessPointRemoved(String),
    /// Signal strength update for a specific access point (AP object path, new strength percentage).
    SignalStrengthChanged(String, u8),
    /// Active connection state change.
    ConnectionStateChanged(ConnectionState),
    /// Background error event notification.
    Error(String),
}

/// Lifecycle states of a Wi-Fi connection attempt.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum ConnectionState {
    /// Disconnected state.
    Disconnected,
    /// Connection request in progress.
    Connecting,
    /// Successfully connected to target network (SSID).
    Connected(String),
    /// Connection attempt failed (error message).
    Failed(String),
}
