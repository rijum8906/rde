//! # Master Volume D-Bus Interface (`org.rde.Volume`)
//!
//! Implements the public D-Bus session bus object interface served at object path `/org/rde/Volume`.
//! Exposes master volume controls, mute switches, step configurations, and reactive signals.
//!
//! ## Features
//! - Properties: `Volume`, `Muted`, `Step`, `MinVolume`, `MaxVolume`, `Version`
//! - Methods: `SetVolume`, `IncreaseVolume`, `DecreaseVolume`, `IncreaseVolumeBy`, `DecreaseVolumeBy`,
//!   `ToggleMute`, `SetMute`, `GetVolume`, `GetMuteState`
//! - Signals: `VolumeChanged`, `MuteChanged`
//!
//! ## Related
//! - [`crate::backend::VolumeBackend`]
//! - [`crate::domain::models::VolumeState`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::sync::Arc;

use rde_core::errors::RdeResult;
use zbus::interface;

use crate::{
    backend::VolumeBackend,
    domain::models::{MAX_VOLUME, MIN_VOLUME},
};

/// Public D-Bus object interface exposing the master volume control service.
pub struct VolumeInterface {
    /// Shared backend audio engine reference.
    backend: Arc<VolumeBackend>,
}

impl VolumeInterface {
    /// Creates a new `VolumeInterface` wrapping a freshly initialized `VolumeBackend`.
    ///
    /// # Errors
    /// Returns `RdeError` if backend initialization fails.
    pub async fn new() -> RdeResult<Self> {
        let backend = Arc::new(VolumeBackend::new()?);
        Ok(Self { backend })
    }

    /// Creates a new `VolumeInterface` with an existing backend instance.
    ///
    /// Useful for testing and custom dependency injection.
    pub fn with_backend(backend: Arc<VolumeBackend>) -> Self {
        Self { backend }
    }

    /// Internal helper to update master volume and emit `VolumeChanged` signal.
    async fn apply_volume(
        &self,
        emitter: &zbus::object_server::SignalEmitter<'_>,
        volume: u8,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Request backend to persist volume change
        let applied_vol = self
            .backend
            .set_volume(volume)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom VolumeChanged signal to notify listening UI clients
        if let Err(e) = Self::emit_volume_changed(emitter, applied_vol).await {
            tracing::warn!("Failed to emit VolumeChanged signal: {}", e);
        }

        Ok(())
    }

    /// Internal helper to update master mute and emit `MuteChanged` signal.
    async fn apply_mute(
        &self,
        emitter: &zbus::object_server::SignalEmitter<'_>,
        muted: bool,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Request backend to update mute state
        self.backend
            .set_mute(muted)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom MuteChanged signal to notify listening UI clients
        if let Err(e) = Self::emit_mute_changed(emitter, muted).await {
            tracing::warn!("Failed to emit MuteChanged signal: {}", e);
        }

        Ok(())
    }
}

/// D-Bus interface implementation for `org.rde.Volume`.
#[interface(name = "org.rde.Volume")]
impl VolumeInterface {
    // =================================
    // PROPERTIES
    // =================================

    /// Read-write D-Bus property returning current master volume percentage (0-100).
    ///
    /// # Errors
    /// Returns D-Bus error if audio hardware query fails.
    #[zbus(property(emits_changed_signal = "false"))]
    pub async fn volume(&self) -> zbus::fdo::Result<u8> {
        self.backend
            .get_volume()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Read-write D-Bus property setter for master volume percentage.
    ///
    /// Clamps value between `0..=100` and emits `VolumeChanged` signal.
    ///
    /// # Parameters
    /// - `emitter`: D-Bus signal emitter for dispatching change events.
    /// - `volume`: Target volume percentage.
    ///
    /// # Errors
    /// Returns D-Bus error if volume update fails.
    #[zbus(property)]
    pub async fn set_volume(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        volume: u8,
    ) -> zbus::fdo::Result<()> {
        self.apply_volume(&emitter, volume).await
    }

    /// Read-write D-Bus property indicating whether master audio is muted.
    ///
    /// # Errors
    /// Returns D-Bus error if audio hardware query fails.
    #[zbus(property(emits_changed_signal = "false"))]
    pub async fn muted(&self) -> zbus::fdo::Result<bool> {
        self.backend
            .get_mute()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Read-write D-Bus property setter for master audio mute state.
    ///
    /// Emits `MuteChanged` signal on update.
    ///
    /// # Parameters
    /// - `emitter`: D-Bus signal emitter for dispatching change events.
    /// - `muted`: `true` to mute, `false` to unmute.
    ///
    /// # Errors
    /// Returns D-Bus error if mute state assignment fails.
    #[zbus(property)]
    pub async fn set_muted(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        muted: bool,
    ) -> zbus::fdo::Result<()> {
        self.apply_mute(&emitter, muted).await
    }

    /// Read-write D-Bus property returning the default step size for volume increments/decrements.
    #[zbus(property)]
    pub fn step(&self) -> zbus::fdo::Result<u8> {
        Ok(self.backend.get_step())
    }

    /// Read-write D-Bus property setter updating the default step size.
    ///
    /// # Parameters
    /// - `step`: New default step size (minimum 1).
    #[zbus(property)]
    pub fn set_step(&self, step: u8) -> zbus::fdo::Result<()> {
        self.backend.set_step(step);
        Ok(())
    }

    /// Read-only D-Bus property returning the minimum allowed volume percentage (0).
    #[zbus(property)]
    pub fn min_volume(&self) -> zbus::fdo::Result<u8> {
        Ok(MIN_VOLUME)
    }

    /// Read-only D-Bus property returning the maximum allowed volume percentage (100).
    #[zbus(property)]
    pub fn max_volume(&self) -> zbus::fdo::Result<u8> {
        Ok(MAX_VOLUME)
    }

    /// Read-only D-Bus property returning the service Cargo package version.
    #[zbus(property)]
    pub fn version(&self) -> zbus::fdo::Result<String> {
        Ok(env!("CARGO_PKG_VERSION").to_string())
    }

    // =================================
    // METHODS
    // =================================

    /// D-Bus method to set absolute master volume (0-100).
    ///
    /// Emits `VolumeChanged` signal upon change.
    ///
    /// # Parameters
    /// - `volume`: Absolute target volume percentage.
    ///
    /// # Errors
    /// Returns D-Bus error if audio hardware update fails.
    #[zbus(name = "SetVolume")]
    pub async fn set_volume_method(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        volume: u8,
    ) -> zbus::fdo::Result<()> {
        self.apply_volume(&emitter, volume).await
    }

    /// D-Bus method to increase master volume by the configured default step size.
    ///
    /// Emits `VolumeChanged` signal upon change.
    ///
    /// # Errors
    /// Returns D-Bus error if volume increment fails.
    #[zbus(name = "IncreaseVolume")]
    pub async fn increase_volume(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Perform increment via backend
        let new_vol = self
            .backend
            .increase_volume()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom VolumeChanged signal
        if let Err(e) = Self::emit_volume_changed(&emitter, new_vol).await {
            tracing::warn!("Failed to emit VolumeChanged signal: {}", e);
        }

        Ok(())
    }

    /// D-Bus method to decrease master volume by the configured default step size.
    ///
    /// Emits `VolumeChanged` signal upon change.
    ///
    /// # Errors
    /// Returns D-Bus error if volume decrement fails.
    #[zbus(name = "DecreaseVolume")]
    pub async fn decrease_volume(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Perform decrement via backend
        let new_vol = self
            .backend
            .decrease_volume()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom VolumeChanged signal
        if let Err(e) = Self::emit_volume_changed(&emitter, new_vol).await {
            tracing::warn!("Failed to emit VolumeChanged signal: {}", e);
        }

        Ok(())
    }

    /// D-Bus method to increase master volume by a custom step size.
    ///
    /// Emits `VolumeChanged` signal upon change.
    ///
    /// # Parameters
    /// - `step`: Custom delta percentage to add.
    ///
    /// # Errors
    /// Returns D-Bus error if volume increment fails.
    #[zbus(name = "IncreaseVolumeBy")]
    pub async fn increase_volume_by(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        step: u8,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Perform increment with custom step
        let new_vol = self
            .backend
            .increase_volume_by(step)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom VolumeChanged signal
        if let Err(e) = Self::emit_volume_changed(&emitter, new_vol).await {
            tracing::warn!("Failed to emit VolumeChanged signal: {}", e);
        }

        Ok(())
    }

    /// D-Bus method to decrease master volume by a custom step size.
    ///
    /// Emits `VolumeChanged` signal upon change.
    ///
    /// # Parameters
    /// - `step`: Custom delta percentage to subtract.
    ///
    /// # Errors
    /// Returns D-Bus error if volume decrement fails.
    #[zbus(name = "DecreaseVolumeBy")]
    pub async fn decrease_volume_by(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        step: u8,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Perform decrement with custom step
        let new_vol = self
            .backend
            .decrease_volume_by(step)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom VolumeChanged signal
        if let Err(e) = Self::emit_volume_changed(&emitter, new_vol).await {
            tracing::warn!("Failed to emit VolumeChanged signal: {}", e);
        }

        Ok(())
    }

    /// D-Bus method to toggle master mute state.
    ///
    /// Inverts current mute status and emits `MuteChanged` signal.
    ///
    /// # Errors
    /// Returns D-Bus error if toggling mute fails.
    #[zbus(name = "ToggleMute")]
    pub async fn toggle_mute(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Step 1: Toggle mute state via backend
        let new_muted = self
            .backend
            .toggle_mute()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        // Step 2: Emit custom MuteChanged signal
        if let Err(e) = Self::emit_mute_changed(&emitter, new_muted).await {
            tracing::warn!("Failed to emit MuteChanged signal: {}", e);
        }

        Ok(())
    }

    /// D-Bus method to explicitly set the master mute state.
    ///
    /// Emits `MuteChanged` signal upon change.
    ///
    /// # Parameters
    /// - `muted`: `true` to mute, `false` to unmute.
    ///
    /// # Errors
    /// Returns D-Bus error if mute assignment fails.
    #[zbus(name = "SetMute")]
    pub async fn set_mute(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        muted: bool,
    ) -> zbus::fdo::Result<()> {
        self.apply_mute(&emitter, muted).await
    }

    /// D-Bus method to get current master volume percentage (0-100).
    ///
    /// # Returns
    /// Master volume percentage.
    ///
    /// # Errors
    /// Returns D-Bus error if audio hardware query fails.
    #[zbus(name = "GetVolume")]
    pub async fn get_volume(&self) -> zbus::fdo::Result<u8> {
        self.backend
            .get_volume()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// D-Bus method to get current master mute state.
    ///
    /// # Returns
    /// `true` if muted, `false` otherwise.
    ///
    /// # Errors
    /// Returns D-Bus error if audio hardware query fails.
    #[zbus(name = "GetMuteState")]
    pub async fn get_mute_state(&self) -> zbus::fdo::Result<bool> {
        self.backend
            .get_mute()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    // =================================
    // SIGNALS
    // =================================

    /// D-Bus signal emitted whenever the master volume percentage changes.
    ///
    /// # Parameters
    /// - `new_volume`: Resulting volume percentage (0-100).
    #[zbus(signal, name = "VolumeChanged")]
    pub async fn emit_volume_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        new_volume: u8,
    ) -> zbus::Result<()>;

    /// D-Bus signal emitted whenever the master playback mute state changes.
    ///
    /// # Parameters
    /// - `muted`: Resulting mute state flag.
    #[zbus(signal, name = "MuteChanged")]
    pub async fn emit_mute_changed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        muted: bool,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infra::mock::InMemoryAudioController;

    fn create_test_iface(initial_vol: u8, initial_muted: bool) -> VolumeInterface {
        let mock = Arc::new(InMemoryAudioController::new(initial_vol, initial_muted));
        let backend = Arc::new(VolumeBackend::with_controller(mock, 5));
        VolumeInterface::with_backend(backend)
    }

    #[tokio::test]
    async fn test_dbus_interface_properties() {
        let iface = create_test_iface(45, false);

        assert_eq!(iface.volume().await.unwrap(), 45);
        assert!(!iface.muted().await.unwrap());
        assert_eq!(iface.min_volume().unwrap(), 0);
        assert_eq!(iface.max_volume().unwrap(), 100);
        assert_eq!(iface.step().unwrap(), 5);
        assert_eq!(iface.version().unwrap(), env!("CARGO_PKG_VERSION"));

        iface.set_step(12).unwrap();
        assert_eq!(iface.step().unwrap(), 12);
    }

    #[tokio::test]
    async fn test_dbus_interface_methods() {
        let iface = create_test_iface(60, true);

        assert_eq!(iface.get_volume().await.unwrap(), 60);
        assert!(iface.get_mute_state().await.unwrap());
    }
}
