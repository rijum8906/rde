//! # RDE Theme Manager Library (`rde-theme`)
//!
//! `rde-theme` is a decoupled microservice within the Riju Desktop Environment (RDE).
//! It provides centralized visual appearance management by generating and synchronizing
//! Material 3 color palettes, typography settings, and theme configurations across
//! GTK, Qt, and native RDE components.
//!
//! ## Features
//! - Material 3 (M3) dynamic color generation and tonal palette synthesis
//! - Persistent theme database under `$XDG_DATA_HOME/rde/rde-theme`
//! - Theme creation from a single source color, install, activate, and delete
//! - Color scheme management (light/dark mode) with WCAG contrast compliance
//! - Session D-Bus interface (`org.rde.Theme`) with typed FDO errors and signals
//! - Unix socket supervision task for `rde-daemon`
//! - Application lifecycle management with daemon integration
//!
//! ## Architecture
//! - **app**: Application singleton ([`app::App`]), event loop, and supervision task
//! - **handler**: Routing and handling of supervisor requests and responses
//! - **constants**: Service name, D-Bus contract, storage layout, and retry policy
//! - **dbus**: D-Bus interface definitions and service exposure
//! - **domain**: Theme models, color helpers, and the Material 3 palette engine
//! - **theme_store**: Registry and manifest persistence for installed themes
//! - **paths**: XDG-compliant theme database locations
//! - **backend**: Manifest to palette resolution and Qt/KDE color scheme output
//! - **file_utils**: Atomic configuration file helpers
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

pub mod app;
pub mod backend;
pub mod constants;
pub mod dbus;
pub mod domain;
mod file_utils;
pub mod handler;
pub mod paths;
pub mod theme_store;
