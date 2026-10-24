//! # Theme Backends
//!
//! Resolves stored themes into palettes through the [`ThemeBackend`] trait and
//! renders them for each desktop toolkit.

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
