//! # D-Bus Interface Module
//!
//! Defines the public D-Bus interface (`org.rde.Brightness`) for brightness control.
//! Exposes D-Bus properties, methods, and signals for system integration.
//!
//! ## D-Bus Interface: `org.rde.Brightness`
//!
//! ### Properties
//! - `version` (String, Read-Only): Service version string
//! - `brightness` (u32, Read/Write): Raw brightness value (0 to max_brightness)
//! - `brightness_percentage` (u32, Read/Write): Brightness as percentage (0-100)
//! - `max_brightness` (u32, Read-Only): Hardware maximum brightness value
//!
//! ### Methods
//! - `IncreaseBrightness(u32) -> u32`: Increase brightness by step percentage
//! - `DecreaseBrightness(u32) -> u32`: Decrease brightness by step percentage
//!
//! ### Signals
//! - `BrightnessChanged(u32)`: Emitted when brightness changes (carries percentage value)
//!
//! ## Related
//! - [`crate::backend::BrightnessBackend`]
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
