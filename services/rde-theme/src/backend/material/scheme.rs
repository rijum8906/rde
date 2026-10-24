//! # Material 3 Scheme Computation
//!
//! Expands a [`SeedColor`] into the semantic roles of a light, dark, or
//! contrast-enhanced scheme.

use material_color_utilities::dynamiccolor::{DynamicSchemeBuilder, Variant};

use crate::domain::{palette::Palette, theme::ColorScheme};

use super::seed::SeedColor;

/// Material 3 scheme variant including its contrast level.
///
/// Each variant maps onto the primitive parameters Material Color Utilities
/// expects: whether the palette is dark and how much extra contrast to apply.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MaterialScheme {
    /// Standard light scheme.
    Light,
    /// Light scheme with medium contrast boost.
    LightMediumContrast,
    /// Light scheme with maximum contrast boost.
    LightHighContrast,
    /// Standard dark scheme.
    Dark,
    /// Dark scheme with medium contrast boost.
    DarkMediumContrast,
    /// Dark scheme with maximum contrast boost.
    DarkHighContrast,
}

impl MaterialScheme {
    /// Maps the user-facing light/dark preference onto a standard scheme.
    pub const fn from_color_scheme(color_scheme: ColorScheme) -> Self {
        match color_scheme {
            ColorScheme::Light => Self::Light,
            ColorScheme::Dark => Self::Dark,
        }
    }

    /// Returns whether the scheme produces a dark palette.
    pub const fn is_dark(self) -> bool {
        matches!(
            self,
            Self::Dark | Self::DarkMediumContrast | Self::DarkHighContrast
        )
    }

    /// Returns the contrast level passed to Material Color Utilities.
    pub const fn contrast_level(self) -> f64 {
        match self {
            Self::Light | Self::Dark => 0.0,
            Self::LightMediumContrast | Self::DarkMediumContrast => 0.5,
            Self::LightHighContrast | Self::DarkHighContrast => 1.0,
        }
    }
}

/// Builder that expands a seed color into a Material 3 palette.
///
/// The builder owns the seed, so generating a light and a dark palette from the
/// same theme reuses the same source color.
pub struct MaterialPaletteBuilder {
    /// Seed color the scheme is derived from.
    seed: SeedColor,

    /// Material 3 scheme variant controlling hue and chroma mapping.
    variant: Variant,
}

impl MaterialPaletteBuilder {
    /// Creates a builder from a seed color.
    pub fn new(seed: SeedColor) -> Self {
        Self {
            seed,
            variant: Variant::TonalSpot,
        }
    }

    /// Selects a different Material 3 scheme variant.
    ///
    /// Defaults to [`Variant::TonalSpot`], the balanced Material You variant.
    pub fn with_variant(mut self, variant: Variant) -> Self {
        self.variant = variant;
        self
    }

    /// Generates the palette for a scheme.
    ///
    /// # Parameters
    /// - `scheme`: light/dark variant and contrast level to generate
    ///
    /// # Returns
    /// The palette with every semantic color role populated.
    pub fn build(&self, scheme: MaterialScheme) -> Palette {
        // Step 1: Ask Material Color Utilities for a dynamic scheme. The
        // builder derives all tonal palettes from the seed color.
        let dynamic_scheme = DynamicSchemeBuilder::default()
            .source_color_hct(self.seed.hct())
            .variant(self.variant)
            .is_dark(scheme.is_dark())
            .contrast_level(scheme.contrast_level())
            .build();

        // Step 2: Map every semantic role onto the corresponding M3 role.
        Palette {
            primary: dynamic_scheme.primary(),
            on_primary: dynamic_scheme.on_primary(),
            primary_container: dynamic_scheme.primary_container(),
            on_primary_container: dynamic_scheme.on_primary_container(),
            secondary: dynamic_scheme.secondary(),
            on_secondary: dynamic_scheme.on_secondary(),
            secondary_container: dynamic_scheme.secondary_container(),
            on_secondary_container: dynamic_scheme.on_secondary_container(),
            tertiary: dynamic_scheme.tertiary(),
            on_tertiary: dynamic_scheme.on_tertiary(),
            tertiary_container: dynamic_scheme.tertiary_container(),
            on_tertiary_container: dynamic_scheme.on_tertiary_container(),
            error: dynamic_scheme.error(),
            on_error: dynamic_scheme.on_error(),
            error_container: dynamic_scheme.error_container(),
            on_error_container: dynamic_scheme.on_error_container(),
            background: dynamic_scheme.background(),
            on_background: dynamic_scheme.on_background(),
            surface: dynamic_scheme.surface(),
            surface_dim: dynamic_scheme.surface_dim(),
            surface_bright: dynamic_scheme.surface_bright(),
            on_surface: dynamic_scheme.on_surface(),
            surface_variant: dynamic_scheme.surface_variant(),
            on_surface_variant: dynamic_scheme.on_surface_variant(),
            surface_container_lowest: dynamic_scheme.surface_container_lowest(),
            surface_container_low: dynamic_scheme.surface_container_low(),
            surface_container: dynamic_scheme.surface_container(),
            surface_container_high: dynamic_scheme.surface_container_high(),
            surface_container_highest: dynamic_scheme.surface_container_highest(),
            surface_tint: dynamic_scheme.surface_tint(),
            inverse_surface: dynamic_scheme.inverse_surface(),
            inverse_on_surface: dynamic_scheme.inverse_on_surface(),
            inverse_primary: dynamic_scheme.inverse_primary(),
            outline: dynamic_scheme.outline(),
            outline_variant: dynamic_scheme.outline_variant(),
            shadow: dynamic_scheme.shadow(),
            scrim: dynamic_scheme.scrim(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::color::format_hex_color;

    fn palette(color_scheme: ColorScheme) -> Palette {
        let seed = SeedColor::from_hex("#6DD6DA").expect("valid seed");
        MaterialPaletteBuilder::new(seed).build(MaterialScheme::from_color_scheme(color_scheme))
    }

    #[test]
    fn palette_contains_every_role() {
        let palette = palette(ColorScheme::Light);
        let roles = palette.role_map();

        assert_eq!(roles.len(), 37);
        assert_eq!(
            roles.get("primary"),
            Some(&format_hex_color(palette.primary))
        );
        assert_eq!(
            roles.get("surface_container_highest"),
            Some(&format_hex_color(palette.surface_container_highest))
        );
        assert!(roles.contains_key("on_surface"));
    }

    #[test]
    fn light_and_dark_schemes_differ() {
        let light = palette(ColorScheme::Light);
        let dark = palette(ColorScheme::Dark);

        assert_ne!(light.surface, dark.surface);
        assert_ne!(light.on_surface, dark.on_surface);
    }

    #[test]
    fn palette_tracks_the_seed_color() {
        let teal = MaterialPaletteBuilder::new(SeedColor::from_hex("#006A6A").expect("teal"))
            .build(MaterialScheme::Light);
        let orange = MaterialPaletteBuilder::new(SeedColor::from_hex("#FF6200").expect("orange"))
            .build(MaterialScheme::Light);

        assert_ne!(teal.primary, orange.primary);
    }

    #[test]
    fn contrast_levels_are_ordered() {
        assert!(!MaterialScheme::Light.is_dark());
        assert!(MaterialScheme::DarkHighContrast.is_dark());
        assert_eq!(MaterialScheme::Light.contrast_level(), 0.0);
        assert_eq!(MaterialScheme::DarkHighContrast.contrast_level(), 1.0);
    }
}
