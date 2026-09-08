//! # Domain Models and Constants (`rde-volume`)
//!
//! Provides the core domain entities, audio state representations, and volume configuration
//! constants for the `rde-volume` microservice.
//!
//! ## Features
//! - Master volume and mute state snapshot struct (`VolumeState`)
//! - Service limits and step constants (`MIN_VOLUME`, `MAX_VOLUME`, `DEFAULT_STEP`)
//! - Standard D-Bus interface and object path identifiers
//!
//! ## Related
//! - [`crate::backend::VolumeBackend`]
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

use serde::{Deserialize, Serialize};

/// Default percentage step increment/decrement used when adjusting volume without a specified step.
pub const DEFAULT_STEP: u8 = 5;

/// Minimum valid volume percentage supported by the master volume control.
pub const MIN_VOLUME: u8 = 0;

/// Maximum valid volume percentage supported by the master volume control.
pub const MAX_VOLUME: u8 = 100;

/// Primary well-known D-Bus session service name claimed by this microservice.
pub const DBUS_SERVICE_NAME: &str = "org.rde.Volume";

/// Canonical D-Bus object path exposing the master volume control interface.
pub const DBUS_OBJECT_PATH: &str = "/org/rde/Volume";

/// Canonical D-Bus interface name implemented on the volume object path.
pub const DBUS_INTERFACE_NAME: &str = "org.rde.Volume";

/// Snapshot representation of the master audio state.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct VolumeState {
    /// Current master volume percentage between 0 and 100 inclusive.
    pub volume: u8,

    /// Whether playback audio is currently muted.
    pub muted: bool,

    /// Configured default step percentage for incremental volume adjustments.
    pub step: u8,
}

impl VolumeState {
    /// Creates a new `VolumeState` instance, automatically clamping `volume` to `0..=100`.
    ///
    /// # Parameters
    /// - `volume`: Master volume percentage (clamped to `[MIN_VOLUME, MAX_VOLUME]`).
    /// - `muted`: Playback mute flag.
    /// - `step`: Default delta step for volume increments/decrements (minimum 1).
    ///
    /// # Returns
    /// A sanitized `VolumeState` struct instance.
    pub fn new(volume: u8, muted: bool, step: u8) -> Self {
        // Step 1: Clamp volume strictly between MIN_VOLUME and MAX_VOLUME
        let clamped_volume = volume.clamp(MIN_VOLUME, MAX_VOLUME);

        // Step 2: Ensure step is at least 1 percentage point to prevent zero-delta loops
        let sanitized_step = step.max(1);

        Self {
            volume: clamped_volume,
            muted,
            step: sanitized_step,
        }
    }
}

impl Default for VolumeState {
    /// Returns the default baseline volume state (0% volume, unmuted, step 5).
    fn default() -> Self {
        Self {
            volume: MIN_VOLUME,
            muted: false,
            step: DEFAULT_STEP,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_volume_state_creation_and_clamping() {
        let state = VolumeState::new(150, false, 0);
        assert_eq!(state.volume, 100);
        assert!(!state.muted);
        assert_eq!(state.step, 1);

        let state_normal = VolumeState::new(65, true, 10);
        assert_eq!(state_normal.volume, 65);
        assert!(state_normal.muted);
        assert_eq!(state_normal.step, 10);
    }
}
