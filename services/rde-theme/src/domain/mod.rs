//! # Domain Models & Business Logic
//!
//! Pure theme models shared by every layer of the service. The domain knows
//! nothing about toolkits, file formats, or D-Bus: it defines identifiers,
//! manifests, semantic color roles, and the preference stored between runs.
//!
//! ## Modules
//! - [`color`][]: hexadecimal color parsing and canonical formatting
//! - [`palette`][]: toolkit-neutral semantic color roles
//! - [`theme`][]: validated theme identifiers, manifests, and resolved themes
//! - [`theme_config`][]: the `themes.toml` registry model
//!
//! ## Related
//! - [`crate::backend`][]: generates palettes and writes toolkit output
//! - [`crate::theme_store`][]: persists these models
//! - [`crate::dbus::iface::ThemeInterface`]: publishes them on D-Bus
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
pub mod palette;
pub mod theme;
pub mod theme_config;
