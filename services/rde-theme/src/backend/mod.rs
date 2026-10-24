//! # Theme Backends
//!
//! Turns stored theme definitions into the palettes that consumers apply, and
//! renders those palettes for each desktop toolkit. This is the seam where the
//! persistence layer meets the color engine, and where toolkit writers live:
//! Qt and KDE today, with GTK CSS served by [`gtk`] and the Freedesktop Portal
//! planned, all without touching storage or D-Bus code.
//!
//! ## Modules
//! - [`material`]: Material 3 palette generation, the default [`ThemeBackend`]
//! - [`qt`]: writes qt5ct/qt6ct and KDE color schemes from a resolved theme
//! - [`gtk`]: renders GTK CSS `@define-color` overrides from a palette
//!
//! ## Responsibilities
//! - Palette generation from a manifest's source color
//! - Resolution of a manifest plus a color scheme into a [`Theme`]
//! - Toolkit output generation, isolated in one module per toolkit
//!
//! ## Related
//! - [`crate::domain::palette::Palette`][]: toolkit-neutral color roles
//! - [`crate::domain::theme::ThemeManifest`][]: source of truth for a theme
//! - [`crate::theme_store::ThemeStore`][]: caller
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use rde_core::errors::RdeResult;

use crate::domain::{
    palette::Palette,
    theme::{ColorScheme, Theme, ThemeManifest},
};

pub mod gtk;
pub mod material;
pub mod qt;

pub use material::MaterialBackend;

/// Color engine that derives palettes from theme definitions.
///
/// Backends perform no I/O; the store owns persistence and the D-Bus interface
/// owns signalling, which keeps this layer pure and easy to test. The default
/// implementation is [`MaterialBackend`].
pub trait ThemeBackend {
    /// Generates a palette for a hexadecimal source color.
    ///
    /// # Parameters
    /// - `source_color`: seed color in any supported hexadecimal form
    /// - `color_scheme`: light or dark variant to generate
    ///
    /// # Errors
    /// Returns [`rde_core::errors::RdeError::InvalidValue`] when the source
    /// color cannot be parsed.
    fn palette(&self, source_color: &str, color_scheme: ColorScheme) -> RdeResult<Palette>;

    /// Resolves a manifest into a theme with a generated palette.
    ///
    /// # Parameters
    /// - `manifest`: stored theme definition
    /// - `color_scheme`: scheme the palette should be generated for
    ///
    /// # Errors
    /// Returns the error produced by [`ThemeBackend::palette`].
    fn resolve(&self, manifest: &ThemeManifest, color_scheme: ColorScheme) -> RdeResult<Theme> {
        let palette = self.palette(&manifest.source_color, color_scheme)?;

        Ok(Theme {
            manifest: manifest.clone(),
            color_scheme,
            palette,
        })
    }
}
