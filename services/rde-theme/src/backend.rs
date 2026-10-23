//! # Theme Backend
//!
//! Turns stored theme definitions into the palettes that consumers apply. This
//! is the seam where the persistence layer meets the Material 3 color engine,
//! and where future toolkit writers (GTK CSS, Qt palettes, Freedesktop Portal)
//! will plug in without touching storage or D-Bus code.
//!
//! ## Responsibilities
//! - Palette generation from a manifest's source color
//! - Resolution of a manifest plus a color scheme into a [`Theme`]
//! - A single place for future toolkit output generation
//!
//! ## Related
//! - [`crate::domain::material::MaterialColorPalette`][]: palette engine
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
    material::MaterialColorPalette,
    theme::{ColorScheme, Theme, ThemeManifest},
};

/// Stateless engine translating theme definitions into concrete palettes.
///
/// The backend performs no I/O; the store owns persistence and the D-Bus
/// interface owns signalling, which keeps this layer pure and easy to test.
pub struct ThemeBackend;

impl ThemeBackend {
    /// Generates the Material 3 palette for a hexadecimal source color.
    ///
    /// # Parameters
    /// - `source_color`: seed color in any supported hexadecimal form
    /// - `color_scheme`: light or dark variant to generate
    ///
    /// # Errors
    /// Returns [`rde_core::errors::RdeError::InvalidValue`] when the source
    /// color cannot be parsed.
    pub fn palette(
        source_color: &str,
        color_scheme: ColorScheme,
    ) -> RdeResult<MaterialColorPalette> {
        MaterialColorPalette::from_source_color(source_color, color_scheme)
    }

    /// Resolves a manifest into a theme with a generated palette.
    ///
    /// # Parameters
    /// - `manifest`: stored theme definition
    /// - `color_scheme`: scheme the palette should be generated for
    ///
    /// # Errors
    /// Returns [`rde_core::errors::RdeError::InvalidValue`] when the manifest's
    /// source color is not a valid hexadecimal color.
    pub fn resolve(manifest: &ThemeManifest, color_scheme: ColorScheme) -> RdeResult<Theme> {
        let palette = Self::palette(&manifest.source_color, color_scheme)?;

        Ok(Theme {
            manifest: manifest.clone(),
            color_scheme,
            palette,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::theme::ThemeId;

    fn manifest() -> ThemeManifest {
        ThemeManifest::new(ThemeId::new("ocean").expect("valid id"), "#006A6A")
            .expect("valid color")
    }

    #[test]
    fn resolve_keeps_the_manifest_and_scheme() {
        let manifest = manifest();
        let theme = ThemeBackend::resolve(&manifest, ColorScheme::Dark).expect("resolved theme");

        assert_eq!(theme.manifest, manifest);
        assert_eq!(theme.color_scheme, ColorScheme::Dark);
        assert_eq!(
            theme.palette,
            manifest.palette(ColorScheme::Dark).expect("palette")
        );
    }

    #[test]
    fn palette_rejects_invalid_source_colors() {
        assert!(ThemeBackend::palette("not-a-color", ColorScheme::Light).is_err());
    }
}
