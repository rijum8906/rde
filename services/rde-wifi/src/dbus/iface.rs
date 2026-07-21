use rde_core::errors::RdeResult;
use zbus::interface;

use crate::{backend::WifiBackend, domain::models::AccessPointInfo};

pub struct WifiInterface {
    backend: WifiBackend,
}

impl WifiInterface {
    pub async fn new() -> RdeResult<Self> {
        let backend = WifiBackend::new().await?;

        Ok(Self { backend })
    }
}

#[interface(name = "org.rde.wifi")]
impl WifiInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// API Version of the Wi-Fi service.
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        let version = env!("CARGO_PKG_VERSION");
        Ok(version.to_string())
    }

    /// Whether the Wi-Fi interface is enabled or not.
    #[zbus(property)]
    pub async fn enabled(&self) -> zbus::fdo::Result<bool> {
        let is_wifi_enabled = self
            .backend
            .is_wifi_enabled()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(is_wifi_enabled)
    }

    /// Enable or disable the Wi-Fi interface.
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

        // Emit custom EnabledChanged D-Bus signal
        if let Err(e) = Self::emit_enabled_changed(&emitter, enabled).await {
            tracing::error!("Failed to emit EnabledChanged signal: {}", e);
        }
        Ok(())
    }

    /// List of available/visible Wi-Fi access points.
    #[zbus(property(emits_changed_signal = "false"))]
    pub async fn networks(&self) -> zbus::fdo::Result<Vec<AccessPointInfo>> {
        let networks = self
            .backend
            .get_available_networks()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(networks)
    }

    /// List of all saved Wi-Fi network SSIDs.
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
    /// This method is non-blocking, requests the scan, and emits ScanCompleted on success.
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

    /// Gets details of the currently connected Wi-Fi connection.
    pub async fn get_current_connection(&self) -> zbus::fdo::Result<Vec<AccessPointInfo>> {
        let current = self
            .backend
            .get_current_connection()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(current.into_iter().collect())
    }

    /// Forgets/deletes a saved Wi-Fi network connection profile.
    pub async fn forgot_device(&self, ssid: &str) -> zbus::fdo::Result<()> {
        self.backend
            .forget_network(ssid)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(())
    }

    /// Connects to a Wi-Fi network with password and emits ConnStateChanged events.
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

    /// Connects to a saved Wi-Fi network and emits ConnStateChanged events.
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

    /// Disconnects from the current network and emits ConnStateChanged event.
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

    /// Signal emitted when a Wi-Fi scan completes.
    #[zbus(signal, name = "ScanCompleted")]
    pub async fn scan_completed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::Result<()>;

    /// Signal emitted when the Wi-Fi enable state changes.
    #[zbus(signal, name = "EnabledChanged")]
    pub async fn emit_enabled_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        enabled: bool,
    ) -> zbus::Result<()>;

    /// Signal emitted when the connection state changes.
    #[zbus(signal, name = "ConnStateChanged")]
    pub async fn emit_conn_state_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        state: &str,
        ssid: &str,
    ) -> zbus::Result<()>;
}
