//! # GTK Theme Backend
//!
//! Renders the active palette for GTK 3 and GTK 4 applications. GTK has no
//! palette daemon either: colors reach applications through the `gtk.css`
//! override loaded after the active theme, which is what [`css`] produces.
//!
//! ## Status
//! CSS emission is implemented. Writing the file into `~/.config/gtk-3.0` and
//! `~/.config/gtk-4.0`, plus `settings.ini` and Portal synchronization, remain
//! planned, mirroring how the Qt backend is applied.
//!
//! ## Related
//! - [`crate::domain::palette::Palette`][]: color source
//! - [`crate::backend::qt`][]: equivalent writer for Qt and KDE
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod css;

pub use css::render_css;
