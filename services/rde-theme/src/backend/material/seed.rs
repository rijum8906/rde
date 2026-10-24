//! # Source Color (Seed)
//!
//! Parses a theme's source color and converts it into the HCT space Material color
//! utilities operate on.

use material_color_utilities::hct::Hct;
use rde_core::errors::RdeResult;

use crate::domain::color::parse_hex_color;

/// Seed color used to generate a palette.
///
/// The seed is stored in HCT, the perceptual space Material color utilities use
/// to pick accessible tonal values, and keeps the packed ARGB it was created
/// from.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SeedColor {
    /// Packed opaque ARGB seed color.
    argb: u32,

    /// Perceptual HCT representation of the seed.
    hct: Hct,
}

impl SeedColor {
    /// Builds a seed from a hexadecimal color.
    ///
    /// # Parameters
    /// - `value`: color in `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB` form
    ///
    /// # Errors
    /// Returns [`rde_core::errors::RdeError::InvalidValue`] when the value is
    /// not a valid hexadecimal color.
    pub fn from_hex(value: &str) -> RdeResult<Self> {
        Ok(Self::from_argb(parse_hex_color(value)?))
    }

    /// Builds a seed from a packed ARGB color.
    ///
    /// # Parameters
    /// - `argb`: packed ARGB color; alpha is ignored by palette generation
    pub fn from_argb(argb: u32) -> Self {
        Self {
            argb,
            hct: Hct::from_int(argb),
        }
    }

    /// Returns the packed ARGB color the seed was created from.
    pub fn argb(&self) -> u32 {
        self.argb
    }

    /// Returns a copy of the seed's HCT value for a scheme builder.
    pub fn hct(&self) -> Hct {
        self.hct.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::constants::{DEFAULT_THEME_SOURCE_COLOR, DEFAULT_THEME_SOURCE_COLOR_ARGB};

    #[test]
    fn hex_and_argb_seeds_are_equivalent() {
        let from_hex =
            SeedColor::from_hex(DEFAULT_THEME_SOURCE_COLOR).expect("valid default source color");
        let from_argb = SeedColor::from_argb(DEFAULT_THEME_SOURCE_COLOR_ARGB);

        assert_eq!(from_hex, from_argb);
        assert_eq!(from_hex.argb(), DEFAULT_THEME_SOURCE_COLOR_ARGB);
    }

    #[test]
    fn invalid_hex_colors_are_rejected() {
        assert!(SeedColor::from_hex("not-a-color").is_err());
        assert!(SeedColor::from_hex("#12345").is_err());
    }
}
