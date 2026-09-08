//! # ALSA Hardware Mixer Controller (`rde-volume`)
//!
//! Provides the concrete Linux ALSA driver implementation for interacting with system
//! sound cards, volume controls, and playback mute switches.
//!
//! ## Features
//! - Automatic discovery of master playback mixer controls ("Master", "Speaker", "Headphone", "PCM")
//! - Multi-channel and mono playback volume querying and synchronization
//! - Hardware playback mute switch control with software state fallback
//! - Thread-safe synchronous ALSA C-binding encapsulation
//!
//! ## Related
//! - [`crate::infra::AudioController`]
//! - [`alsa::Mixer`]
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
    Mutex,
    atomic::{AtomicBool, Ordering},
};

use alsa::{
    Mixer,
    mixer::{SelemChannelId, SelemId},
};
use rde_core::errors::{RdeError, RdeResult};

use crate::infra::AudioController;

/// Concrete Linux ALSA implementation of `AudioController`.
pub struct AlsaController {
    /// Mutex-wrapped ALSA mixer instance for thread-safe access.
    mixer: Mutex<Mixer>,

    /// Simple element identifier targeted for master volume and mute controls.
    selem_id: SelemId,

    /// Software mute flag fallback for devices without hardware mute switches.
    cached_mute: AtomicBool,
}

impl AlsaController {
    /// Creates a new `AlsaController` by connecting to the default ALSA sound card.
    ///
    /// Searches for standard master controls ("Master", "Speaker", "Headphone", "PCM")
    /// or selects the first available playback element.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` or `RdeError::HardwareNotFound` if opening the mixer
    /// or discovering playback controls fails.
    pub fn new() -> RdeResult<Self> {
        Self::with_card_and_control("default", "Master")
    }

    /// Creates a new `AlsaController` targeting a specific ALSA sound card and control name.
    ///
    /// # Parameters
    /// - `card_name`: ALSA card identifier (e.g. `"default"`, `"hw:0"`).
    /// - `control_name`: Primary control name to target (e.g. `"Master"`).
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` or `RdeError::HardwareNotFound` if mixer initialization fails.
    pub fn with_card_and_control(card_name: &str, control_name: &str) -> RdeResult<Self> {
        // Step 1: Attempt to open the ALSA mixer for the requested sound card
        let mixer = Mixer::new(card_name, false)
            .or_else(|_| Mixer::new("hw:0", false))
            .map_err(|e| {
                RdeError::Hardware(format!("Failed to open ALSA mixer on {}: {}", card_name, e))
            })?;

        // Step 2: Try primary control name and common fallback candidate names
        let candidates = [control_name, "Master", "Speaker", "Headphone", "PCM"];
        let mut target_id = None;

        for &candidate in &candidates {
            let id = SelemId::new(candidate, 0);
            if let Some(selem) = mixer.find_selem(&id) {
                if selem.has_playback_volume() {
                    tracing::info!(
                        "Using ALSA mixer control: '{}' (card: '{}')",
                        candidate,
                        card_name
                    );
                    target_id = Some(id);
                    break;
                }
            }
        }

        // Step 3: Fall back to the first mixer element that supports playback volume
        let selem_id = match target_id {
            Some(id) => id,
            None => {
                let mut found = None;
                for elem in mixer.iter() {
                    if let Some(selem) = alsa::mixer::Selem::new(elem) {
                        if selem.has_playback_volume() {
                            let id = selem.get_id();
                            tracing::info!(
                                "Selected fallback ALSA mixer control: '{}' (index: {})",
                                id.get_name().unwrap_or_default(),
                                id.get_index()
                            );
                            found = Some(id);
                            break;
                        }
                    }
                }
                found.ok_or_else(|| {
                    RdeError::HardwareNotFound(
                        "No playback volume control found on ALSA mixer".to_string(),
                    )
                })?
            }
        };

        // Step 4: Check initial mute state from hardware switch if present
        let mut initial_muted = false;
        if let Some(selem) = mixer.find_selem(&selem_id) {
            if selem.has_playback_switch() {
                if let Ok(sw) = selem.get_playback_switch(SelemChannelId::FrontLeft) {
                    initial_muted = sw == 0;
                }
            }
        }

        Ok(Self {
            mixer: Mutex::new(mixer),
            selem_id,
            cached_mute: AtomicBool::new(initial_muted),
        })
    }
}

impl AudioController for AlsaController {
    /// Queries the current playback volume percentage from ALSA.
    ///
    /// # Execution Steps
    /// 1. Locks the internal mixer mutex.
    /// 2. Locates the targeted simple mixer element (`Selem`).
    /// 3. Resolves the primary audio playback channel (mono vs stereo).
    /// 4. Reads raw ALSA volume and converts it to a 0-100 percentage.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` on ALSA query failure.
    fn get_volume(&self) -> RdeResult<u8> {
        let mixer_guard = self
            .mixer
            .lock()
            .map_err(|e| RdeError::Hardware(format!("Failed to acquire ALSA mixer lock: {}", e)))?;

        let selem = mixer_guard.find_selem(&self.selem_id).ok_or_else(|| {
            RdeError::HardwareNotFound("Target ALSA mixer control element not found".to_string())
        })?;

        // Step 1: Determine active playback channel
        let channel =
            if selem.is_playback_mono() || selem.has_playback_channel(SelemChannelId::FrontLeft) {
                SelemChannelId::FrontLeft
            } else if selem.has_playback_channel(SelemChannelId::FrontRight) {
                SelemChannelId::FrontRight
            } else {
                SelemChannelId::Unknown
            };

        // Step 2: Read raw channel volume
        let raw_volume = selem
            .get_playback_volume(channel)
            .map_err(|e| RdeError::Hardware(format!("Failed to get playback volume: {}", e)))?;

        // Step 3: Map raw ALSA range to integer percentage (0-100)
        let (min, max) = selem.get_playback_volume_range();
        let percentage = if max > min {
            let clamped = raw_volume.clamp(min, max);
            let percent = ((clamped - min) as f64 * 100.0 / (max - min) as f64).round() as u8;
            percent.min(100)
        } else {
            0
        };

        Ok(percentage)
    }

    /// Sets the master playback volume percentage on ALSA.
    ///
    /// # Execution Steps
    /// 1. Clamps target percentage to `0..=100`.
    /// 2. Locks mixer mutex and retrieves simple element.
    /// 3. Maps percentage to raw ALSA hardware volume units.
    /// 4. Dispatches volume update across all channels.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` on ALSA update failure.
    fn set_volume(&self, percentage: u8) -> RdeResult<()> {
        let clamped_pct = percentage.min(100);

        let mixer_guard = self
            .mixer
            .lock()
            .map_err(|e| RdeError::Hardware(format!("Failed to acquire ALSA mixer lock: {}", e)))?;

        let selem = mixer_guard.find_selem(&self.selem_id).ok_or_else(|| {
            RdeError::HardwareNotFound("Target ALSA mixer control element not found".to_string())
        })?;

        // Step 1: Map percentage to raw ALSA volume value with rounding
        let (min, max) = selem.get_playback_volume_range();
        let raw_volume = if max > min {
            min + ((clamped_pct as i64 * (max - min) + 50) / 100)
        } else {
            min
        };

        // Step 2: Set volume for all channels
        if selem.set_playback_volume_all(raw_volume).is_err() {
            // Fallback: individually set FrontLeft and FrontRight channels if supported
            if selem.has_playback_channel(SelemChannelId::FrontLeft) {
                let _ = selem.set_playback_volume(SelemChannelId::FrontLeft, raw_volume);
            }
            if selem.has_playback_channel(SelemChannelId::FrontRight) {
                let _ = selem.set_playback_volume(SelemChannelId::FrontRight, raw_volume);
            }
        }

        Ok(())
    }

    /// Queries the master playback mute state.
    ///
    /// Checks hardware playback switch; if unsupported, returns cached software state.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` on ALSA query failure.
    fn get_mute(&self) -> RdeResult<bool> {
        let mixer_guard = self
            .mixer
            .lock()
            .map_err(|e| RdeError::Hardware(format!("Failed to acquire ALSA mixer lock: {}", e)))?;

        let selem = mixer_guard.find_selem(&self.selem_id).ok_or_else(|| {
            RdeError::HardwareNotFound("Target ALSA mixer control element not found".to_string())
        })?;

        // Step 1: Query hardware switch if supported
        if selem.has_playback_switch() {
            let channel = if selem.is_playback_mono()
                || selem.has_playback_channel(SelemChannelId::FrontLeft)
            {
                SelemChannelId::FrontLeft
            } else if selem.has_playback_channel(SelemChannelId::FrontRight) {
                SelemChannelId::FrontRight
            } else {
                SelemChannelId::Unknown
            };

            let sw = selem
                .get_playback_switch(channel)
                .map_err(|e| RdeError::Hardware(format!("Failed to get playback switch: {}", e)))?;

            // 0 indicates switch is off (audio muted)
            Ok(sw == 0)
        } else {
            // Fall back to software state
            Ok(self.cached_mute.load(Ordering::Relaxed))
        }
    }

    /// Sets the master playback mute state.
    ///
    /// Updates hardware playback switch (0 = muted, 1 = unmuted) and caches software state.
    ///
    /// # Errors
    /// Returns `RdeError` on ALSA update failure.
    fn set_mute(&self, muted: bool) -> RdeResult<()> {
        let mixer_guard = self
            .mixer
            .lock()
            .map_err(|e| RdeError::Hardware(format!("Failed to acquire ALSA mixer lock: {}", e)))?;

        let selem = mixer_guard.find_selem(&self.selem_id).ok_or_else(|| {
            RdeError::HardwareNotFound("Target ALSA mixer control element not found".to_string())
        })?;

        let switch_val = if muted { 0 } else { 1 };

        // Step 1: Update hardware playback switch if present
        if selem.has_playback_switch() && selem.set_playback_switch_all(switch_val).is_err() {
            if selem.has_playback_channel(SelemChannelId::FrontLeft) {
                let _ = selem.set_playback_switch(SelemChannelId::FrontLeft, switch_val);
            }
            if selem.has_playback_channel(SelemChannelId::FrontRight) {
                let _ = selem.set_playback_switch(SelemChannelId::FrontRight, switch_val);
            }
        }

        // Step 2: Cache software mute state
        self.cached_mute.store(muted, Ordering::Relaxed);

        Ok(())
    }
}
