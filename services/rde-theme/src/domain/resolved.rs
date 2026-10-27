//! # Resolved Interop Payload
//!
//! Models [`ResolvedTheme`], the unified interop contract consumed across D-Bus,
//! cache files, and desktop applications.
//!
//! Shipped static variant files and the dynamically seeded theme both produce
//! exactly this shape. Consumers must never branch on [`VariantKind`].

use serde::{Deserialize, Serialize};
use std::{fmt, ops::Deref};
use thiserror::Error;
use zbus::zvariant::{Optional, Type};

use crate::domain::identity::{ThemeId, VariantId};

/// Supported schema version for resolved theme payloads.
pub const SUPPORTED_RESOLVED_SCHEMA_VERSION: u32 = 1;

/// Neutral fallback seed color (`#4285f4`) used when no user seed is available.
pub const FALLBACK_SEED_COLOR: &str = "#4285f4";

/// Default error seed (Material red `#ba1a1a`) used until the user picks one.
pub const DEFAULT_ERROR_SEED: &str = "#ba1a1a";

/// Validation errors when parsing hexadecimal color strings.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum ColorError {
    /// Color string does not start with `#`.
    #[error("color must start with '#', got '{0}'")]
    MissingHashPrefix(String),

    /// Color string is not exactly 7 characters (`#RRGGBB`).
    #[error("color must be exactly 7 characters (#RRGGBB), got length {0}")]
    InvalidLength(usize),

    /// Color contains non-hexadecimal characters.
    #[error("invalid hexadecimal character '{0}' in color")]
    InvalidHexChar(char),
}

/// A validated `#RRGGBB` color string without alpha channel.
///
/// Ensures at parse-time that variant files cannot inject malformed color strings.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Type)]
#[serde(try_from = "String", into = "String")]
pub struct Color(String);

impl Color {
    /// Validates and constructs a new [`Color`].
    ///
    /// Accepts only `#RRGGBB` (uppercase or lowercase hexadecimal, no alpha).
    ///
    /// # Errors
    /// Returns [`ColorError`] if format is invalid.
    pub fn new(s: impl AsRef<str>) -> Result<Self, ColorError> {
        let text = s.as_ref();

        // Step 1: Enforce exact 7-character length (#RRGGBB).
        if text.len() != 7 {
            return Err(ColorError::InvalidLength(text.len()));
        }

        // Step 2: Enforce leading '#'.
        if !text.starts_with('#') {
            return Err(ColorError::MissingHashPrefix(text.to_string()));
        }

        // Step 3: Enforce all 6 remaining characters are valid hexadecimal.
        for ch in text[1..].chars() {
            if !ch.is_ascii_hexdigit() {
                return Err(ColorError::InvalidHexChar(ch));
            }
        }

        Ok(Self(text.to_string()))
    }

    /// Constructs a [`Color`] from RGB byte components.
    #[must_use]
    pub fn from_rgb(r: u8, g: u8, b: u8) -> Self {
        Self(format!("#{r:02x}{g:02x}{b:02x}"))
    }

    /// Constructs the neutral fallback seed color.
    ///
    /// # Returns
    /// A [`Color`] equal to [`FALLBACK_SEED_COLOR`], used when no user-provided
    /// seed color is available.
    #[must_use]
    pub fn fallback() -> Self {
        // `FALLBACK_SEED_COLOR` is a compile-time valid `#RRGGBB` literal.
        Self(FALLBACK_SEED_COLOR.to_string())
    }

    /// Constructs a [`Color`] from a 32-bit ARGB integer, discarding the alpha channel.
    #[must_use]
    pub fn from_argb_u32(argb: u32) -> Self {
        let r = ((argb >> 16) & 0xFF) as u8;
        let g = ((argb >> 8) & 0xFF) as u8;
        let b = (argb & 0xFF) as u8;
        Self::from_rgb(r, g, b)
    }

    /// Returns the color string as a string slice.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Deref for Color {
    type Target = str;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl AsRef<str> for Color {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

/// The four seed colors the built-in dynamic theme renders its palettes from.
///
/// Each role family owns one seed: primary drives the accent family and the
/// neutral surfaces, while secondary, tertiary, and error each drive their own
/// tonal palette. Clients that only want to change the accent can keep sending
/// the other three seeds unchanged.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ColorSeeds {
    /// Seed of the primary family and of every neutral surface role.
    pub primary: Color,

    /// Seed of the secondary family.
    pub secondary: Color,

    /// Seed of the tertiary family.
    pub tertiary: Color,

    /// Seed of the error family.
    pub error: Color,
}

impl ColorSeeds {
    /// Builds a seed set where every family uses the same color.
    #[must_use]
    pub fn uniform(seed: &Color) -> Self {
        Self {
            primary: seed.clone(),
            secondary: seed.clone(),
            tertiary: seed.clone(),
            error: seed.clone(),
        }
    }

    /// Builds the fallback seed set: neutral blue families and the default error red.
    #[must_use]
    pub fn fallback() -> Self {
        // Both literals are compile-time valid `#RRGGBB` values.
        let primary = Color::fallback();
        let error = Color::new(DEFAULT_ERROR_SEED).unwrap_or_else(|_| Color::fallback());
        Self {
            primary: primary.clone(),
            secondary: primary.clone(),
            tertiary: primary,
            error,
        }
    }
}

impl fmt::Display for Color {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl TryFrom<String> for Color {
    type Error = ColorError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}

impl From<Color> for String {
    fn from(color: Color) -> Self {
        color.0
    }
}

/// The fully-resolved theme an application consumes.
///
/// This is the interop contract: shipped variant files and the computed
/// dynamic theme both produce exactly this shape. Consumers must never
/// branch on [`VariantKind`].
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Type)]
pub struct ResolvedTheme {
    /// Payload schema version. Bump on breaking field changes.
    pub schema_version: u32,

    /// Unique identifier of the theme that produced this payload.
    pub theme_id: ThemeId,

    /// Variant selected from the theme.
    pub variant: VariantId,

    /// Origin type of the variant (static file or dynamically computed).
    pub kind: VariantKind,

    /// Complete set of Material 3 semantic color roles.
    pub colors: ColorRoles,

    /// Desktop typography settings.
    pub typography: Typography,

    /// UI corner radii shape specifications.
    pub shape: Shape,

    /// Animation motion durations and curves.
    pub motion: Motion,
}

/// Classification of variant source generation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[serde(rename_all = "kebab-case")]
pub enum VariantKind {
    /// Backed by a shipped, pre-computed `*.json` file.
    Static,

    /// Computed dynamically at runtime from the user's seed colors.
    Dynamic,
}

/// Complete set of Material Design 3 semantic color roles.
///
/// All fields are mandatory [`Color`] values to ensure completeness at compile-time
/// and deserialization time.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Type)]
pub struct ColorRoles {
    pub primary: Color,
    pub on_primary: Color,
    pub primary_container: Color,
    pub on_primary_container: Color,
    pub secondary: Color,
    pub on_secondary: Color,
    pub secondary_container: Color,
    pub on_secondary_container: Color,
    pub tertiary: Color,
    pub on_tertiary: Color,
    pub tertiary_container: Color,
    pub on_tertiary_container: Color,
    pub error: Color,
    pub on_error: Color,
    pub error_container: Color,
    pub on_error_container: Color,
    pub background: Color,
    pub on_background: Color,
    pub surface: Color,
    pub on_surface: Color,
    pub surface_variant: Color,
    pub on_surface_variant: Color,
    pub surface_container_lowest: Color,
    pub surface_container_low: Color,
    pub surface_container: Color,
    pub surface_container_high: Color,
    pub surface_container_highest: Color,
    pub outline: Color,
    pub outline_variant: Color,
    pub shadow: Color,
    pub scrim: Color,
    pub inverse_surface: Color,
    pub inverse_on_surface: Color,
    pub inverse_primary: Color,
}

/// Typography specification.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Type)]
pub struct Typography {
    /// Standard UI proportional font family.
    pub font_family: String,

    /// Monospace code font family.
    #[serde(default)]
    pub mono_family: Optional<String>,
}

impl Default for Typography {
    fn default() -> Self {
        Self {
            font_family: "Cantarell, Inter, sans-serif".to_string(),
            mono_family: Some("monospace".to_string()).into(),
        }
    }
}

/// Corner radii geometry tokens for UI surfaces.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Type)]
pub struct Shape {
    pub radius_extra_small: f32,
    pub radius_small: f32,
    pub radius_medium: f32,
    pub radius_large: f32,
    pub radius_extra_large: f32,
}

impl Default for Shape {
    fn default() -> Self {
        Self {
            radius_extra_small: 4.0,
            radius_small: 8.0,
            radius_medium: 12.0,
            radius_large: 16.0,
            radius_extra_large: 28.0,
        }
    }
}

/// Motion duration and easing curve parameters.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Type)]
pub struct Motion {
    /// Short micro-interaction duration in milliseconds.
    pub duration_short_ms: u32,

    /// Medium interaction duration in milliseconds.
    pub duration_medium_ms: u32,

    /// Long interaction duration in milliseconds.
    pub duration_long_ms: u32,

    /// Standard cubic bezier transition curve.
    pub curve_standard: String,

    /// Emphasized cubic bezier transition curve.
    pub curve_emphasized: String,
}

impl Default for Motion {
    fn default() -> Self {
        Self {
            duration_short_ms: 150,
            duration_medium_ms: 300,
            duration_long_ms: 500,
            curve_standard: "cubic-bezier(0.2, 0.0, 0.0, 1.0)".to_string(),
            curve_emphasized: "cubic-bezier(0.2, 0.0, 0.0, 1.25)".to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_color() {
        assert!(Color::new("#123456").is_ok());
        assert!(Color::new("#abcdef").is_ok());
        assert!(Color::new("#ABCDEF").is_ok());
        assert_eq!(Color::from_rgb(0x12, 0x34, 0x56).as_str(), "#123456");
    }

    #[test]
    fn test_fallback_color_is_valid() {
        assert_eq!(Color::fallback().as_str(), FALLBACK_SEED_COLOR);
    }

    #[test]
    fn test_invalid_color_rgb_three_digits_rejected() {
        assert_eq!(Color::new("#RGB"), Err(ColorError::InvalidLength(4)));
        assert_eq!(Color::new("#abc"), Err(ColorError::InvalidLength(4)));
    }

    #[test]
    fn test_invalid_color_word_name_rejected() {
        assert_eq!(Color::new("red"), Err(ColorError::InvalidLength(3)));
    }

    #[test]
    fn test_invalid_color_with_alpha_rejected() {
        assert_eq!(Color::new("#12345678"), Err(ColorError::InvalidLength(9)));
    }

    #[test]
    fn test_invalid_color_missing_hash() {
        assert_eq!(
            Color::new("1234567"),
            Err(ColorError::MissingHashPrefix("1234567".into()))
        );
    }

    #[test]
    fn test_invalid_color_invalid_hex() {
        assert_eq!(Color::new("#12345g"), Err(ColorError::InvalidHexChar('g')));
    }
}
