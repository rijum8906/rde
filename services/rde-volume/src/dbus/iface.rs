//! # Master Volume D-Bus Interface (`org.rde.Volume`)
//!
//! Serves the public `org.rde.Volume` object at `/org/rde/Volume`, exposing
//! playback and capture state as properties and relative adjustment as methods.

use std::sync::Arc;

use rde_core::errors::RdeResult;
use tracing::warn;
use zbus::{interface, object_server::SignalEmitter};

use crate::backend::VolumeBackend;

/// Public D-Bus object interface exposing the master volume control service.
pub struct VolumeInterface {
    /// Shared backend audio engine reference.
    backend: Arc<VolumeBackend>,
}

impl VolumeInterface {
    /// Creates a new `VolumeInterface` wrapping a freshly initialized `VolumeBackend`.
    ///
    /// Opening the mixer performs no asynchronous work, so this constructor is
    /// synchronous and can run during application initialisation.
    ///
    /// # Errors
    /// Returns `RdeError` if backend initialization fails.
    pub fn new() -> RdeResult<Self> {
        let backend = Arc::new(VolumeBackend::new()?);
        Ok(Self { backend })
    }

    /// Creates a new `VolumeInterface` with an existing backend instance.
    ///
    /// Useful for testing and custom dependency injection.
    pub fn with_backend(backend: Arc<VolumeBackend>) -> Self {
        Self { backend }
    }

    /// Announces a master volume change made outside of the `Volume` setter.
    ///
    /// `zbus` emits `PropertiesChanged` for property setters on its own, but a
    /// method such as `IncreaseVolumeBy` bypasses the property machinery, so the
    /// property is republished here.
    ///
    /// # Parameters
    /// - `emitter`: emitter bound to the served object
    async fn publish_volume(&self, emitter: &SignalEmitter<'_>) {
        if let Err(error) = self.volume_changed(emitter).await {
            warn!(%error, "Failed to emit the Volume PropertiesChanged signal");
        }
    }

    /// Announces a mute change made outside of the `Muted` setter.
    ///
    /// # Parameters
    /// - `emitter`: emitter bound to the served object
    async fn publish_muted(&self, emitter: &SignalEmitter<'_>) {
        if let Err(error) = self.muted_changed(emitter).await {
            warn!(%error, "Failed to emit the Muted PropertiesChanged signal");
        }
    }
}

/// D-Bus interface implementation for `org.rde.Volume`.
#[interface(name = "org.rde.Volume")]
impl VolumeInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// Read-only property holding the service package version.
    #[zbus(property)]
    pub fn version(&self) -> String {
        env!("CARGO_PKG_VERSION").to_string()
    }

    /// Read-write property holding the master volume percentage (0-100).
    ///
    /// # Errors
    /// Returns a D-Bus failure when the mixer query fails.
    #[zbus(property)]
    pub async fn volume(&self) -> zbus::fdo::Result<u8> {
        self.backend
            .get_volume()
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Sets the master volume percentage.
    ///
    /// `zbus` emits `PropertiesChanged` automatically once this returns `Ok`.
    ///
    /// # Parameters
    /// - `volume`: target percentage, clampable to `0..=100` by the backend
    ///
    /// # Errors
    /// Returns a D-Bus failure when the mixer rejects the write.
    #[zbus(property)]
    pub async fn set_volume(&self, volume: u8) -> zbus::fdo::Result<()> {
        self.backend
            .set_volume(volume)
            .await
            .map(|_| ())
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Read-write property reporting whether playback is muted.
    ///
    /// # Errors
    /// Returns a D-Bus failure when the mixer query fails.
    #[zbus(property)]
    pub async fn muted(&self) -> zbus::fdo::Result<bool> {
        self.backend
            .get_mute()
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Sets the master playback mute state.
    ///
    /// `zbus` emits `PropertiesChanged` automatically once this returns `Ok`.
    ///
    /// # Parameters
    /// - `muted`: `true` to mute playback, `false` to unmute it
    ///
    /// # Errors
    /// Returns a D-Bus failure when the mixer rejects the write.
    #[zbus(property)]
    pub async fn set_muted(&self, muted: bool) -> zbus::fdo::Result<()> {
        self.backend
            .set_mute(muted)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Read-write property holding the microphone volume percentage (0-100).
    ///
    /// # Errors
    /// Returns a D-Bus failure when the capture control is missing or the query
    /// fails.
    #[zbus(property)]
    pub async fn microphone_volume(&self) -> zbus::fdo::Result<u8> {
        self.backend
            .get_microphone_volume()
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Sets the microphone capture volume percentage.
    ///
    /// `zbus` emits `PropertiesChanged` automatically once this returns `Ok`.
    ///
    /// # Parameters
    /// - `volume`: target percentage, clampable to `0..=100` by the backend
    ///
    /// # Errors
    /// Returns a D-Bus failure when the capture control cannot be written.
    #[zbus(property)]
    pub async fn set_microphone_volume(&self, volume: u8) -> zbus::fdo::Result<()> {
        self.backend
            .set_microphone_volume(volume)
            .await
            .map(|_| ())
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Read-write property reporting whether microphone capture is muted.
    ///
    /// # Errors
    /// Returns a D-Bus failure when the device has no capture control or the
    /// query fails.
    #[zbus(property)]
    pub async fn microphone_muted(&self) -> zbus::fdo::Result<bool> {
        self.backend
            .get_microphone_mute()
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    /// Sets the microphone capture mute state.
    ///
    /// `zbus` emits `PropertiesChanged` automatically once this returns `Ok`.
    ///
    /// # Parameters
    /// - `muted`: `true` to mute capture, `false` to unmute it
    ///
    /// # Errors
    /// Returns a D-Bus failure when the capture control cannot be written.
    #[zbus(property)]
    pub async fn set_microphone_muted(&self, muted: bool) -> zbus::fdo::Result<()> {
        self.backend
            .set_microphone_mute(muted)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))
    }

    // =================================
    // METHODS
    // =================================

    /// Adjusts the master volume upward by `step` percentage points.
    ///
    /// # Parameters
    /// - `step`: percentage points to add, capped at 100
    ///
    /// # Errors
    /// Returns a D-Bus failure when the volume cannot be read or written.
    #[zbus(name = "IncreaseVolumeBy")]
    pub async fn increase_volume_by(
        &self,
        step: u8,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Apply the increment through the backend.
        self.backend
            .increase_volume_by(step)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        // Step 2: Republish the changed property.
        self.publish_volume(&emitter).await;
        Ok(())
    }

    /// Adjusts the master volume downward by `step` percentage points.
    ///
    /// # Parameters
    /// - `step`: percentage points to subtract, saturated at 0
    ///
    /// # Errors
    /// Returns a D-Bus failure when the volume cannot be read or written.
    #[zbus(name = "DecreaseVolumeBy")]
    pub async fn decrease_volume_by(
        &self,
        step: u8,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Apply the decrement through the backend.
        self.backend
            .decrease_volume_by(step)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        // Step 2: Republish the changed property.
        self.publish_volume(&emitter).await;
        Ok(())
    }

    /// Inverts the master mute state.
    ///
    /// # Errors
    /// Returns a D-Bus failure when the mute state cannot be read or written.
    #[zbus(name = "ToggleMute")]
    pub async fn toggle_mute(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Flip the switch through the backend.
        self.backend
            .toggle_mute()
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        // Step 2: Republish the changed property.
        self.publish_muted(&emitter).await;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::mock::InMemoryAudioController;

    /// Builds an interface over an in-memory audio controller.
    fn create_test_iface(initial_vol: u8, initial_muted: bool) -> VolumeInterface {
        let mock = Arc::new(InMemoryAudioController::new(initial_vol, initial_muted));
        let backend = Arc::new(VolumeBackend::with_controller(mock, 5));
        VolumeInterface::with_backend(backend)
    }

    #[tokio::test]
    async fn properties_report_the_backend_state() {
        let iface = create_test_iface(45, false);

        assert_eq!(iface.version(), env!("CARGO_PKG_VERSION"));
        assert_eq!(iface.volume().await.unwrap(), 45);
        assert!(!iface.muted().await.unwrap());
        assert_eq!(iface.microphone_volume().await.unwrap(), 45);
        assert!(!iface.microphone_muted().await.unwrap());
    }

    #[tokio::test]
    async fn properties_write_through_to_the_backend() {
        let iface = create_test_iface(60, true);

        iface.set_volume(80).await.unwrap();
        assert_eq!(iface.volume().await.unwrap(), 80);

        iface.set_muted(false).await.unwrap();
        assert!(!iface.muted().await.unwrap());

        iface.set_microphone_volume(30).await.unwrap();
        assert_eq!(iface.microphone_volume().await.unwrap(), 30);

        iface.set_microphone_muted(true).await.unwrap();
        assert!(iface.microphone_muted().await.unwrap());
    }
}
