//! # RDE Brightness Service Library (`rde-brightness`)
//!
//! `rde-brightness` is a lightweight microservice within the Riju Desktop Environment (RDE).
//! It provides hardware brightness control and management for display backlights across
//! various graphics hardware (Intel, AMD, NVIDIA).
//!
//! ## Features
//! - Direct and privileged backlight brightness control via sysfs interface
//! - Percentage-based brightness adjustment (0-100%)
//! - Raw brightness value access for advanced use cases
//! - D-Bus interface (`org.rde.Brightness`) for system integration
//! - Graceful daemon supervision via Unix socket IPC
//! - Hardware abstraction for Intel, AMD, and other backlight drivers
//! - Fallback to privilege escalation (pkexec) for restricted sysfs access
//!
//! ## Architecture
//! - **app**: Application lifecycle, D-Bus setup, daemon supervision
//! - **backend**: Hardware interface abstraction and brightness control
//! - **dbus**: D-Bus interface definitions (properties, methods, signals)
//! - **constants**: Configuration constants for retry logic
//!
//! ## D-Bus Interface: `org.rde.Brightness`
//! Clients interact with brightness control via D-Bus at path `/org/rde/Brightness`:
//! - Properties: brightness, brightness_percentage, max_brightness, version
//! - Methods: IncreaseBrightness, DecreaseBrightness
//! - Signals: BrightnessChanged
//!
//! ## Related
//! - [Linux Backlight Driver Documentation](https://www.kernel.org/doc/html/latest/userspace-api/sysfs-behavior.rst)
//! - [`rde-daemon`](../rde-daemon)
//! - [`rde-ipc`](../../crates/rde-ipc)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod app;
pub mod backend;
pub mod constants;
pub mod dbus;
