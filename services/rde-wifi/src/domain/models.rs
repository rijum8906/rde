use serde::{Deserialize, Serialize};
use zbus::zvariant::{Type, Value};

/// Represents a WiFi access point with all necessary info
#[derive(Debug, Clone, Serialize, Deserialize, Type, Value)]
pub struct AccessPointInfo {
    pub path: String,
    pub ssid: String,
    pub strength: u8, // 0-100
    pub security: SecurityType,
    pub mac_address: String,
    pub frequency: u32,
    pub is_connected: bool,
    pub is_saved: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Type, Value)]
pub enum SecurityType {
    Open,
    Wep,
    Wpa,
    Wpa2,
    Wpa3,
    Enterprise,
    Unknown,
}

/// Events emitted by the backend
#[derive(Debug, Clone)]
pub enum WifiEvent {
    ScanStarted,
    ScanCompleted,
    AccessPointAdded(String), // AP path
    AccessPointRemoved(String),
    SignalStrengthChanged(String, u8), // AP path, new strength
    ConnectionStateChanged(ConnectionState),
    Error(String),
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum ConnectionState {
    Disconnected,
    Connecting,
    Connected(String), // SSID
    Failed(String),    // Error message
}
