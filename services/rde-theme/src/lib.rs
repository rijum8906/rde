//! # RDE Theme Manager Library (`rde-theme`)
//!
//! `rde-theme` is a decoupled microservice within the Riju Desktop Environment (RDE).
//! It provides centralized visual appearance management by generating and synchronizing
//! Material 3 color palettes, typography settings, and theme configurations across
//! GTK, Qt, and native RDE components.
//!
//! ## Features
//! - Material 3 (M3) dynamic color generation and tonal palette synthesis
//! - Cross-toolkit theme synchronization (GTK 3/4, Qt 5/6)
//! - Color scheme management (light/dark mode) with WCAG contrast compliance
//! - Typography and font configuration engine
//! - Session D-Bus interface (`org.rde.Theme`)
//! - Unix socket IPC connection for daemon supervision
//!
//! ## Related
//! - [Material Design 3 Specification](https://m3.material.io/)
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

pub mod backend;
pub mod dbus;
pub mod domain;
