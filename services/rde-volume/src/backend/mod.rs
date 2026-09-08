//! # Volume Backend Engine Module (`rde-volume`)
//!
//! The backend engine orchestrates volume calculation, mute toggling, step handling,
//! and hardware abstraction dispatching for the master audio control.
//!
//! ## Features
//! - Master volume queries and boundary-clamped mutations (0-100%)
//! - Mute state querying, explicit assignment, and atomic toggle logic
//! - Configurable step-based incremental and decremental adjustments
//! - Decoupled hardware driver interaction via `AudioController`
//!
//! ## Related
//! - [`crate::infra::AudioController`]
//! - [`crate::domain::models::VolumeState`]
//! - [`crate::dbus::iface::VolumeInterface`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::sync::{
    Arc,
    atomic::{AtomicU8, Ordering},
};

use rde_core::errors::RdeResult;

use crate::{
    domain::models::{DEFAULT_STEP, MAX_VOLUME, MIN_VOLUME, VolumeState},
    infra::{AudioController, alsa::AlsaController},
};

#[cfg(test)]
mod tests;

/// Central business logic engine managing volume adjustments and hardware interactions.
pub struct VolumeBackend {
    /// Pluggable audio driver controller (ALSA or mock).
    controller: Arc<dyn AudioController>,

    /// Configured default step percentage for volume adjustments.
    step: AtomicU8,
}

impl VolumeBackend {
    /// Creates a new `VolumeBackend` initialized with the default ALSA hardware controller.
    ///
    /// # Errors
    /// Returns `RdeError` if opening the system ALSA mixer fails.
    pub fn new() -> RdeResult<Self> {
        let controller = Arc::new(AlsaController::new()?);
        Ok(Self::with_controller(controller, DEFAULT_STEP))
    }

    /// Creates a new `VolumeBackend` instance with an explicitly provided `AudioController`.
    ///
    /// Useful for dependency injection, mock testing, and custom driver backends.
    ///
    /// # Parameters
    /// - `controller`: Trait object implementing `AudioController`.
    /// - `step`: Default delta step for volume adjustments (minimum 1).
    pub fn with_controller(controller: Arc<dyn AudioController>, step: u8) -> Self {
        Self {
            controller,
            step: AtomicU8::new(step.max(1)),
        }
    }

    /// Queries the current master volume percentage from the audio controller.
    ///
    /// # Returns
    /// Current master volume clamped between 0 and 100.
    ///
    /// # Errors
    /// Returns `RdeError` if the underlying audio driver encounters an error.
    pub async fn get_volume(&self) -> RdeResult<u8> {
        // Step 1: Delegate hardware query to controller
        let raw_vol = self.controller.get_volume()?;

        // Step 2: Ensure returned volume is strictly clamped
        Ok(raw_vol.clamp(MIN_VOLUME, MAX_VOLUME))
    }

    /// Sets the master volume to an absolute percentage value.
    ///
    /// # Parameters
    /// - `volume`: Desired percentage (clamped to `0..=100`).
    ///
    /// # Returns
    /// The clamped volume percentage that was written to hardware.
    ///
    /// # Errors
    /// Returns `RdeError` if writing to the audio controller fails.
    pub async fn set_volume(&self, volume: u8) -> RdeResult<u8> {
        // Step 1: Clamp requested volume to allowed bounds
        let target = volume.clamp(MIN_VOLUME, MAX_VOLUME);

        // Step 2: Update hardware state
        self.controller.set_volume(target)?;

        tracing::info!("Master volume updated to {}%", target);
        Ok(target)
    }

    /// Queries the current master playback mute state.
    ///
    /// # Returns
    /// `true` if audio is muted, `false` otherwise.
    ///
    /// # Errors
    /// Returns `RdeError` if querying the hardware driver fails.
    pub async fn get_mute(&self) -> RdeResult<bool> {
        self.controller.get_mute()
    }

    /// Sets the master playback mute state explicitly.
    ///
    /// # Parameters
    /// - `muted`: `true` to mute playback, `false` to unmute.
    ///
    /// # Errors
    /// Returns `RdeError` if setting the hardware switch fails.
    pub async fn set_mute(&self, muted: bool) -> RdeResult<()> {
        self.controller.set_mute(muted)?;
        tracing::info!("Master playback mute set to {}", muted);
        Ok(())
    }

    /// Toggles the current master mute state (unmuted -> muted, muted -> unmuted).
    ///
    /// # Returns
    /// The new mute state after toggling.
    ///
    /// # Errors
    /// Returns `RdeError` if querying or writing the hardware mute state fails.
    pub async fn toggle_mute(&self) -> RdeResult<bool> {
        // Step 1: Query existing mute state
        let current_muted = self.get_mute().await?;

        // Step 2: Invert the state
        let new_muted = !current_muted;

        // Step 3: Write new state back to hardware
        self.set_mute(new_muted).await?;

        tracing::info!(
            "Master mute toggled from {} to {}",
            current_muted,
            new_muted
        );
        Ok(new_muted)
    }

    /// Returns the currently configured default volume step size.
    pub fn get_step(&self) -> u8 {
        self.step.load(Ordering::Relaxed)
    }

    /// Updates the default step size used for volume changes.
    ///
    /// Enforces a minimum step size of 1 percentage point.
    ///
    /// # Parameters
    /// - `step`: New default step size.
    pub fn set_step(&self, step: u8) {
        let sanitized = step.max(1);
        self.step.store(sanitized, Ordering::Relaxed);
        tracing::info!("Default volume step updated to {}", sanitized);
    }

    /// Increases master volume by the configured default step size.
    ///
    /// # Returns
    /// New volume percentage after increment.
    ///
    /// # Errors
    /// Returns `RdeError` if querying or writing volume fails.
    pub async fn increase_volume(&self) -> RdeResult<u8> {
        let step = self.get_step();
        self.increase_volume_by(step).await
    }

    /// Decreases master volume by the configured default step size.
    ///
    /// # Returns
    /// New volume percentage after decrement.
    ///
    /// # Errors
    /// Returns `RdeError` if querying or writing volume fails.
    pub async fn decrease_volume(&self) -> RdeResult<u8> {
        let step = self.get_step();
        self.decrease_volume_by(step).await
    }

    /// Increases master volume by a specified custom step size.
    ///
    /// Automatically caps the volume at `MAX_VOLUME` (100%).
    ///
    /// # Parameters
    /// - `step`: Percentage to add to current volume.
    ///
    /// # Returns
    /// Resulting volume percentage.
    ///
    /// # Errors
    /// Returns `RdeError` if querying or writing volume fails.
    pub async fn increase_volume_by(&self, step: u8) -> RdeResult<u8> {
        // Step 1: Read current volume
        let current = self.get_volume().await?;

        // Step 2: Compute incremented volume with upper boundary capping
        let new_vol = current.saturating_add(step).min(MAX_VOLUME);

        // Step 3: Apply new volume
        self.set_volume(new_vol).await
    }

    /// Decreases master volume by a specified custom step size.
    ///
    /// Automatically saturates at `MIN_VOLUME` (0%).
    ///
    /// # Parameters
    /// - `step`: Percentage to subtract from current volume.
    ///
    /// # Returns
    /// Resulting volume percentage.
    ///
    /// # Errors
    /// Returns `RdeError` if querying or writing volume fails.
    pub async fn decrease_volume_by(&self, step: u8) -> RdeResult<u8> {
        // Step 1: Read current volume
        let current = self.get_volume().await?;

        // Step 2: Compute decremented volume with lower boundary saturation
        let new_vol = current.saturating_sub(step);

        // Step 3: Apply new volume
        self.set_volume(new_vol).await
    }

    /// Returns a full snapshot of the current audio state (volume, mute, step).
    ///
    /// # Errors
    /// Returns `RdeError` if querying volume or mute states fails.
    pub async fn get_state(&self) -> RdeResult<VolumeState> {
        let volume = self.get_volume().await?;
        let muted = self.get_mute().await?;
        let step = self.get_step();

        Ok(VolumeState::new(volume, muted, step))
    }
}
