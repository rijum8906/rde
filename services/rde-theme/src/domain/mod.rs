//! # Domain Models & Business Logic
//!
//! Defines core data structures representing theme configurations, color palettes,
//! and color scheme preferences. These models encapsulate the business logic for
//! theme management and are serialized over D-Bus interfaces.
//!
//! ## Modules
//! - [`color`][]: hexadecimal color parsing and canonical formatting
//! - [`theme`][]: validated theme identifiers, manifests, and resolved themes
//! - [`theme_config_file`][]: the `themes.toml` registry model
//! - [`material`][]: Material 3 color palette and color role definitions
//! - [`gtk`][]: GTK-specific color palette structures and conversions
//!
//! ## Related
//! - [`crate::dbus::iface::ThemeInterface`]
//! - [`crate::theme_store::ThemeStore`][]: persists these models
//! - [Material Design 3 Color System](https://m3.material.io/styles/color/roles)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod color;
pub mod gtk;
pub mod material;
pub mod theme;
pub mod theme_config_file;
