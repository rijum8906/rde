//! # Infrastructure Layer Module (`rde-volume`)
//!
//! Provides low-level audio driver interfaces, ALSA mixer bindings, and test mocks
//! for hardware-independent unit testing.
//!
//! ## Features
//! - `AudioController` trait defining the abstract audio hardware interface
//! - Real Linux ALSA mixer controller implementation (`AlsaController`)
//! - Mockable audio controller for test isolation
//!
//! ## Related
//! - [`crate::infra::alsa::AlsaController`]
//! - [`crate::infra::mock::MockAudioController`]
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

pub mod alsa;
pub mod mock;

/// Abstract interface for querying and controlling audio hardware playback volume and mute states.
#[cfg_attr(test, mockall::automock)]
pub trait AudioController: Send + Sync {
    /// Queries the current master playback volume as an integer percentage (0-100).
    ///
    /// # Returns
    /// Master volume percentage.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` or `RdeError::HardwareNotFound` on driver failure.
    fn get_volume(&self) -> RdeResult<u8>;

    /// Sets the master playback volume to an absolute integer percentage (0-100).
    ///
    /// # Parameters
    /// - `percentage`: Volume percentage clamped to 0..=100.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` or `RdeError::HardwareNotFound` on driver failure.
    fn set_volume(&self, percentage: u8) -> RdeResult<()>;

    /// Queries whether master playback is currently muted.
    ///
    /// # Returns
    /// `true` if muted, `false` otherwise.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` on driver failure.
    fn get_mute(&self) -> RdeResult<bool>;

    /// Sets the master playback mute state.
    ///
    /// # Parameters
    /// - `muted`: `true` to mute, `false` to unmute.
    ///
    /// # Errors
    /// Returns `RdeError::Hardware` on driver failure.
    fn set_mute(&self, muted: bool) -> RdeResult<()>;
}
