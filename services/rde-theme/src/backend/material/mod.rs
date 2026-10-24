//! # Material 3 Theme Backend
//!
//! Implements [`ThemeBackend`] with Google's Material color utilities, expanding a
//! single seed color into a complete set of semantic roles.

pub mod scheme;
pub mod seed;

use rde_core::errors::RdeResult;

use crate::{
    backend::ThemeBackend,
    domain::{palette::Palette, theme::ColorScheme},
};

pub use scheme::{MaterialPaletteBuilder, MaterialScheme};
pub use seed::SeedColor;

/// Default theme backend: Material 3 dynamic color.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct MaterialBackend;

impl ThemeBackend for MaterialBackend {
    /// Generates the Material 3 palette for a hexadecimal source color.
    ///
    /// # Parameters
    /// - `source_color`: seed color in any supported hexadecimal form
    /// - `color_scheme`: light or dark variant to generate
    ///
    /// # Errors
    /// Returns [`rde_core::errors::RdeError::InvalidValue`] when the source
    /// color cannot be parsed.
    fn palette(&self, source_color: &str, color_scheme: ColorScheme) -> RdeResult<Palette> {
        let seed = SeedColor::from_hex(source_color)?;
        let scheme = MaterialScheme::from_color_scheme(color_scheme);

        Ok(MaterialPaletteBuilder::new(seed).build(scheme))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::theme::{ThemeId, ThemeManifest};

    fn manifest() -> ThemeManifest {
        ThemeManifest::new(ThemeId::new("ocean").expect("valid id"), "#006A6A")
            .expect("valid color")
    }

    #[test]
    fn resolve_keeps_the_manifest_and_scheme() {
        let manifest = manifest();
        let theme = MaterialBackend
            .resolve(&manifest, ColorScheme::Dark)
            .expect("resolved theme");

        assert_eq!(theme.manifest, manifest);
        assert_eq!(theme.color_scheme, ColorScheme::Dark);
        assert_eq!(
            theme.palette,
            MaterialBackend
                .palette("#006A6A", ColorScheme::Dark)
                .expect("palette")
        );
    }

    #[test]
    fn palette_rejects_invalid_source_colors() {
        assert!(
            MaterialBackend
                .palette("not-a-color", ColorScheme::Light)
                .is_err()
        );
    }
}
