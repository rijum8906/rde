//! # Audio Controller Mock Implementations (`rde-volume`)
//!
//! Provides in-memory test mocks and stubs for `AudioController` allowing unit tests
//! to run cleanly in virtualized or CI environments without ALSA audio hardware.
//!
//! ## Features
//! - In-memory simulated audio device (`InMemoryAudioController`)
//! - Mockall-generated `MockAudioController` for fine-grained expectation testing
//!
//! ## Related
//! - [`crate::infra::AudioController`]
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
    atomic::{AtomicBool, AtomicU8, Ordering},
};

use rde_core::errors::RdeResult;

use crate::infra::AudioController;

/// In-memory software implementation of `AudioController` for testing.
pub struct InMemoryAudioController {
    /// Stored volume level (0-100).
    pub volume: AtomicU8,

    /// Stored mute state.
    pub muted: AtomicBool,

    /// Simulated error trigger for error path testing.
    pub error_on_next: Mutex<Option<String>>,
}

impl InMemoryAudioController {
    /// Creates a new `InMemoryAudioController` with specified initial values.
    pub fn new(initial_volume: u8, initial_muted: bool) -> Self {
        Self {
            volume: AtomicU8::new(initial_volume.min(100)),
            muted: AtomicBool::new(initial_muted),
            error_on_next: Mutex::new(None),
        }
    }

    /// Sets an error message to be returned on the next operation.
    pub fn trigger_error(&self, message: &str) {
        if let Ok(mut lock) = self.error_on_next.lock() {
            *lock = Some(message.to_string());
        }
    }

    /// Checks and consumes any pending simulated error.
    fn check_error(&self) -> RdeResult<()> {
        if let Ok(mut lock) = self.error_on_next.lock() {
            if let Some(err) = lock.take() {
                return Err(rde_core::errors::RdeError::Hardware(err));
            }
        }
        Ok(())
    }
}

impl AudioController for InMemoryAudioController {
    fn get_volume(&self) -> RdeResult<u8> {
        self.check_error()?;
        Ok(self.volume.load(Ordering::Relaxed))
    }

    fn set_volume(&self, percentage: u8) -> RdeResult<()> {
        self.check_error()?;
        self.volume.store(percentage.min(100), Ordering::Relaxed);
        Ok(())
    }

    fn get_mute(&self) -> RdeResult<bool> {
        self.check_error()?;
        Ok(self.muted.load(Ordering::Relaxed))
    }

    fn set_mute(&self, muted: bool) -> RdeResult<()> {
        self.check_error()?;
        self.muted.store(muted, Ordering::Relaxed);
        Ok(())
    }
}
