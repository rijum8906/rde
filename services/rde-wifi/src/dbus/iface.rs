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
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        // get the version from Cargo.toml
        let version = env!("CARGO_PKG_VERSION");

        Ok(version.to_string())
    }

    #[zbus(property)]
    pub async fn networks(&self) -> zbus::fdo::Result<Vec<AccessPointInfo>> {
        let networks = self
            .backend
            .get_available_networks()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        Ok(networks)
    }

    // =================================
    // METHODS
    // =================================

    // Requests a scan for available Wi-Fi networks.
    // NOTE: This method just scans for networks, and on success, emits a signal.
    //  This method is non-blocking and returns immediately.
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

    // =================================
    // SIGNALS
    // =================================
    #[zbus(signal, name = "ScanCompleted")]
    pub async fn scan_completed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::Result<()>;
}
