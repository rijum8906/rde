//! # Backend Unit Tests (`rde-volume`)
//!
//! Unit test suite verifying volume calculations, boundary limits, mute toggling,
//! and step behavior against an in-memory audio controller.
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

use super::*;
use crate::infra::mock::InMemoryAudioController;

fn create_test_backend(
    initial_vol: u8,
    initial_muted: bool,
    step: u8,
) -> (VolumeBackend, Arc<InMemoryAudioController>) {
    let mock = Arc::new(InMemoryAudioController::new(initial_vol, initial_muted));
    let backend = VolumeBackend::with_controller(mock.clone(), step);
    (backend, mock)
}

#[tokio::test]
async fn test_get_and_set_volume() {
    let (backend, mock) = create_test_backend(50, false, 5);

    assert_eq!(backend.get_volume().await.unwrap(), 50);

    let new_vol = backend.set_volume(80).await.unwrap();
    assert_eq!(new_vol, 80);
    assert_eq!(backend.get_volume().await.unwrap(), 80);
    assert_eq!(mock.volume.load(std::sync::atomic::Ordering::Relaxed), 80);
}

#[tokio::test]
async fn test_volume_clamping_at_boundaries() {
    let (backend, _mock) = create_test_backend(50, false, 5);

    // Test capping above 100
    let capped = backend.set_volume(150).await.unwrap();
    assert_eq!(capped, 100);
    assert_eq!(backend.get_volume().await.unwrap(), 100);

    // Test 0 lower boundary
    let zero = backend.set_volume(0).await.unwrap();
    assert_eq!(zero, 0);
    assert_eq!(backend.get_volume().await.unwrap(), 0);
}

#[tokio::test]
async fn test_get_set_and_toggle_mute() {
    let (backend, mock) = create_test_backend(50, false, 5);

    assert!(!backend.get_mute().await.unwrap());

    // Explicit set mute true
    backend.set_mute(true).await.unwrap();
    assert!(backend.get_mute().await.unwrap());
    assert!(mock.muted.load(std::sync::atomic::Ordering::Relaxed));

    // Toggle mute
    let toggled = backend.toggle_mute().await.unwrap();
    assert!(!toggled);
    assert!(!backend.get_mute().await.unwrap());

    // Toggle again
    let toggled_again = backend.toggle_mute().await.unwrap();
    assert!(toggled_again);
    assert!(backend.get_mute().await.unwrap());
}

#[tokio::test]
async fn test_step_modifications() {
    let (backend, _mock) = create_test_backend(50, false, 5);

    assert_eq!(backend.get_step(), 5);

    backend.set_step(10);
    assert_eq!(backend.get_step(), 10);

    // Step cannot be set to 0 (minimum 1)
    backend.set_step(0);
    assert_eq!(backend.get_step(), 1);
}

#[tokio::test]
async fn test_increase_and_decrease_volume() {
    let (backend, _mock) = create_test_backend(50, false, 5);

    // Increase by default step (5)
    let vol = backend.increase_volume().await.unwrap();
    assert_eq!(vol, 55);

    // Decrease by default step (5)
    let vol = backend.decrease_volume().await.unwrap();
    assert_eq!(vol, 50);

    // Increase by custom step (20)
    let vol = backend.increase_volume_by(20).await.unwrap();
    assert_eq!(vol, 70);

    // Decrease by custom step (35)
    let vol = backend.decrease_volume_by(35).await.unwrap();
    assert_eq!(vol, 35);
}

#[tokio::test]
async fn test_volume_increase_decrease_saturation() {
    let (backend, _mock) = create_test_backend(95, false, 10);

    // Saturate at 100
    let vol = backend.increase_volume().await.unwrap();
    assert_eq!(vol, 100);

    let vol = backend.increase_volume().await.unwrap();
    assert_eq!(vol, 100);

    // Saturate at 0
    let (backend_low, _mock2) = create_test_backend(5, false, 10);
    let vol = backend_low.decrease_volume().await.unwrap();
    assert_eq!(vol, 0);

    let vol = backend_low.decrease_volume().await.unwrap();
    assert_eq!(vol, 0);
}

#[tokio::test]
async fn test_controller_error_propagation() {
    let (backend, mock) = create_test_backend(50, false, 5);

    mock.trigger_error("Audio hardware disconnected");
    assert!(backend.get_volume().await.is_err());

    mock.trigger_error("Mixer busy");
    assert!(backend.set_volume(60).await.is_err());

    mock.trigger_error("Mute switch error");
    assert!(backend.toggle_mute().await.is_err());
}

#[tokio::test]
async fn test_get_state_snapshot() {
    let (backend, _mock) = create_test_backend(42, true, 8);

    let state = backend.get_state().await.unwrap();
    assert_eq!(state.volume, 42);
    assert!(state.muted);
    assert_eq!(state.step, 8);
}
