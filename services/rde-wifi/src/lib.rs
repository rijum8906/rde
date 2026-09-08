//! # RDE Wi-Fi Service Library (`rde-wifi`)
//!
//! `rde-wifi` is a decoupled microservice within the Riju Desktop Environment (RDE).
//! It provides high-level Wi-Fi network management capabilities by interfacing with
//! Linux's system NetworkManager D-Bus service (`org.freedesktop.NetworkManager`).
//!
//! ## Features
//! - Global application singleton and lifecycle management
//! - NetworkManager system D-Bus proxy interface wrapper
//! - Dynamic access point scanning and connection management
//! - Public session D-Bus interface (`org.rde.wifi`)
//! - Unix socket IPC connection for daemon supervision
//!
//! ## Related
//! - [NetworkManager D-Bus Specification](https://networkmanager.dev/docs/api/latest/)
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
pub mod dbus;
pub mod domain;
pub mod infra;
pub mod ipc;
