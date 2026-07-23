//! # D-Bus Interface Implementation (`org.rde.wifi`)
//!
//! Implements the public D-Bus object interface served at object path `/org/rde/wifi`.
//! Exposes D-Bus properties, methods, and signals for Wi-Fi management.
//!
//! ## Features
//! - D-Bus properties (`version`, `enabled`, `networks`, `saved_networks`, `active_network`)
//! - D-Bus methods (`scan`, `connect`, `disconnect`, `forget`, `set_enabled`)
//! - D-Bus signals (`ScanCompleted`, `EnabledChanged`, `ConnStateChanged`)
//!
//! ## Related
//! - [`crate::backend::WifiBackend`]
//! - [`crate::domain::models::AccessPointInfo`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::errors::RdeResult;
use zbus::interface;

use crate::{backend::WifiBackend, domain::models::AccessPointInfo};

/// D-Bus server interface wrapping the `WifiBackend` instance.
pub struct WifiInterface {
    backend: WifiBackend,
}

impl WifiInterface {
    /// Creates a new `WifiInterface` instance by initializing the underlying `WifiBackend`.
    ///
    /// # Errors
    /// Returns `RdeError` if system D-Bus connection or backend initialization fails.
    pub async fn new() -> RdeResult<Self> {
        let backend = WifiBackend::new().await?;

        Ok(Self { backend })
    }
}

/// Public `org.rde.wifi` D-Bus interface macro implementation.
#[interface(name = "org.rde.wifi")]
impl WifiInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// API Version of the Wi-Fi service (matches Cargo package version).
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        let version = env!("CARGO_PKG_VERSION");
        Ok(version.to_string())
    }

    /// Read-only D-Bus property indicating whether the Wi-Fi radio is enabled.
    #[zbus(property)]
    pub async fn enabled(&self) -> zbus::fdo::Result<bool> {
        let is_wifi_enabled = self
            .backend
            .is_wifi_enabled()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(is_wifi_enabled)
    }

    /// Read-write D-Bus property setter to enable or disable the Wi-Fi radio.
    ///
    /// Emits the `EnabledChanged` D-Bus signal upon state change.
    #[zbus(property)]
    pub async fn set_enabled(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        enabled: bool,
    ) -> zbus::fdo::Result<()> {
        self.backend
            .set_wifi_enabled(enabled)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Emit custom EnabledChanged D-Bus signal to notify listening UI clients
        if let Err(e) = Self::emit_enabled_changed(&emitter, enabled).await {
            tracing::error!("Failed to emit EnabledChanged signal: {}", e);
        }
        Ok(())
    }

    /// Read-only D-Bus property listing all visible/scanned access points.
    #[zbus(property(emits_changed_signal = "false"))]
    pub async fn networks(&self) -> zbus::fdo::Result<Vec<AccessPointInfo>> {
        let networks = self
            .backend
            .get_available_networks()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(networks)
    }

    /// Read-only D-Bus property listing all saved Wi-Fi network SSIDs.
    #[zbus(property)]
    pub async fn saved_networks(&self) -> zbus::fdo::Result<Vec<String>> {
        let saved = self
            .backend
            .get_saved_networks()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(saved)
    }

    // =================================
    // METHODS
    // =================================

    /// Requests a scan for available Wi-Fi networks.
    ///
    /// This method triggers a background scan on the Wi-Fi hardware and emits the `ScanCompleted` D-Bus signal upon completion.
    pub async fn scan(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        if let Err(e) = self.backend.request_scan().await {
            tracing::error!("Scan failed: {}", e);
            return Err(zbus::fdo::Error::Failed(e.to_string()));
        }
        if let Err(e) = Self::scan_completed(&emitter).await {
            tracing::error!("Scan completed failed: {}", e);
            return Err(zbus::fdo::Error::Failed(e.to_string()));
        }
        Ok(())
    }

    /// Gets details of the currently connected Wi-Fi connection as a vector (empty if disconnected).
    pub async fn get_current_connection(&self) -> zbus::fdo::Result<Vec<AccessPointInfo>> {
        let current = self
            .backend
            .get_current_connection()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(current.into_iter().collect())
    }

    /// Forgets/deletes a saved Wi-Fi network connection profile matching `ssid`.
    pub async fn forgot_device(&self, ssid: &str) -> zbus::fdo::Result<()> {
        self.backend
            .forget_network(ssid)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(())
    }

    /// Connects to a Wi-Fi network with passphrase and emits `ConnStateChanged` events.
    pub async fn connect(
        &self,
        ssid: &str,
        password: &str,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let _ = Self::emit_conn_state_changed(&emitter, "Connecting", ssid).await;

        match self.backend.connect_to_network(ssid, Some(password)).await {
            Ok(_) => {
                let _ = Self::emit_conn_state_changed(&emitter, "Connected", ssid).await;
                Ok(())
            }
            Err(e) => {
                let error_msg = e.to_string();
                let _ = Self::emit_conn_state_changed(&emitter, "Failed", &error_msg).await;
                Err(zbus::fdo::Error::Failed(error_msg))
            }
        }
    }

    /// Connects to a previously saved Wi-Fi network without prompting for password, emitting `ConnStateChanged` events.
    pub async fn connect_saved_network(
        &self,
        ssid: &str,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let _ = Self::emit_conn_state_changed(&emitter, "Connecting", ssid).await;

        match self.backend.connect_to_network(ssid, None).await {
            Ok(_) => {
                let _ = Self::emit_conn_state_changed(&emitter, "Connected", ssid).await;
                Ok(())
            }
            Err(e) => {
                let error_msg = e.to_string();
                let _ = Self::emit_conn_state_changed(&emitter, "Failed", &error_msg).await;
                Err(zbus::fdo::Error::Failed(error_msg))
            }
        }
    }

    /// Disconnects from the current network interface and emits the `ConnStateChanged` event.
    pub async fn disconnect(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        match self.backend.disconnect().await {
            Ok(_) => {
                let _ = Self::emit_conn_state_changed(&emitter, "Disconnected", "").await;
                Ok(())
            }
            Err(e) => {
                tracing::error!("Disconnect failed: {}", e);
                Err(zbus::fdo::Error::Failed(e.to_string()))
            }
        }
    }

    // =================================
    // SIGNALS
    // =================================

    /// D-Bus signal emitted when a Wi-Fi spectrum scan completes.
    #[zbus(signal, name = "ScanCompleted")]
    pub async fn scan_completed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::Result<()>;

    /// D-Bus signal emitted when the Wi-Fi hardware enable state toggles.
    #[zbus(signal, name = "EnabledChanged")]
    pub async fn emit_enabled_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        enabled: bool,
    ) -> zbus::Result<()>;

    /// D-Bus signal emitted when connection status changes (Connecting, Connected, Disconnected, Failed).
    #[zbus(signal, name = "ConnStateChanged")]
    pub async fn emit_conn_state_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        state: &str,
        ssid: &str,
    ) -> zbus::Result<()>;
}
