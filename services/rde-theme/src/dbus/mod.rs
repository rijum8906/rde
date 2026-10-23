//! # D-Bus Interface & Service Registration
//!
//! Defines the public D-Bus interface (`org.rde.Theme`) exposed by the theme service.
//! Manages property access, method invocations, and signal emissions for remote
//! theme management and synchronization operations.
//!
//! ## Features
//! - D-Bus object server interface definition
//! - Theme properties (active theme, installed themes, color scheme, source color)
//! - Theme manipulation methods (`SetTheme`, `CreateTheme`, `DeleteTheme`, `SetSourceColor`)
//! - Palette queries as a role-name to `#RRGGBB` map (`GetPalette`)
//! - Standard FDO error mapping and property/signal notifications
//!
//! ## Related
//! - [`crate::theme_store::ThemeStore`][]: authoritative theme state
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
