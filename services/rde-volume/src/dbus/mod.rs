//! # D-Bus Presentation Module (`rde-volume`)
//!
//! Provides the public D-Bus session bus interface for master audio volume
//! and mute control, mapping external invocations to backend logic.
//!
//! ## Features
//! - Public D-Bus interface (`org.rde.Volume`)
//! - Reactive signal emissions (`VolumeChanged`, `MuteChanged`)
//! - Standard property exposure and mutation methods
//!
//! ## Related
//! - [`crate::dbus::iface::VolumeInterface`]
//! - [`crate::backend::VolumeBackend`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod iface;
