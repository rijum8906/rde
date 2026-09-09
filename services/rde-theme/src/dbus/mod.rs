//! # D-Bus Interface & Service Registration
//!
//! Defines the public D-Bus interface (`org.rde.Theme`) exposed by the theme service.
//! Manages property access, method invocations, and signal emissions for remote
//! theme management and synchronization operations.
//!
//! ## Features
//! - D-Bus object server interface definition
//! - Theme property management (active theme, color scheme, available themes)
//! - Theme manipulation methods (set_theme, create_theme, delete_theme)
//! - Dynamic color palette control (set_accent_color, toggle_color_scheme)
//! - Signal emission for theme and palette changes
//!
//! ## Related
//! - [`crate::domain::theme::Theme`]
//! - [`crate::domain::material::MaterialColorPalette`]
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
