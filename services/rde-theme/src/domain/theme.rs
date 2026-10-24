//! # Theme Domain Models
//!
//! Defines the theme concepts persisted by the service: validated theme
//! identifiers, the light/dark preference, the per-theme manifest, and the
//! resolved theme handed to callers and the D-Bus API.
//!
//! ## Models
//! - [`ThemeId`][]: validated, path-safe theme identifier
//! - [`ColorScheme`][]: light or dark appearance preference
//! - [`ThemeManifest`][]: content of `themes/<id>/theme.toml`
//! - [`Theme`][]: manifest resolved into a palette for one scheme
//!
//! ## Features
//! - Identifier validation prevents path traversal before any file is touched
//! - Manifest constructors normalize the source color to `#RRGGBB`
//! - Themes carry a toolkit-neutral [`Palette`], never a toolkit color type
//!
//! ## Related
//! - [`crate::domain::palette::Palette`][]: generated colors
//! - [`crate::domain::theme_config::ThemeRegistry`][]: installed list
//! - [`crate::theme_store`][]: persistence layer
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{fmt, str::FromStr};

use rde_core::errors::{RdeError, RdeResult};
use serde::{Deserialize, Serialize};

use crate::{
    constants::{
        DEFAULT_THEME_DESCRIPTION, DEFAULT_THEME_DISPLAY_NAME, DEFAULT_THEME_ID,
        DEFAULT_THEME_SOURCE_COLOR, DEFAULT_THEME_VERSION, MANIFEST_SCHEMA_VERSION,
        MAX_THEME_ID_LEN,
    },
    domain::{color::normalize_hex_color, palette::Palette},
};

/// System-wide light/dark appearance preference.
///
/// The scheme is global rather than per-theme: a theme describes how colors are
/// derived, while the scheme selects which tonal variant is active.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ColorScheme {
    /// Light tonal palette (default for a fresh installation).
    #[default]
    Light,
    /// Dark tonal palette.
    Dark,
}

impl ColorScheme {
    /// Returns the lowercase identifier used in TOML and on D-Bus.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Light => "light",
            Self::Dark => "dark",
        }
    }

    /// Returns whether this scheme produces a dark palette.
    pub const fn is_dark(self) -> bool {
        matches!(self, Self::Dark)
    }

    /// Returns the opposite scheme.
    pub const fn toggled(self) -> Self {
        match self {
            Self::Light => Self::Dark,
            Self::Dark => Self::Light,
        }
    }
}

impl fmt::Display for ColorScheme {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

impl FromStr for ColorScheme {
    type Err = RdeError;

    /// Parses `light` or `dark`, ignoring surrounding whitespace and case.
    ///
    /// # Errors
    /// Returns [`RdeError::InvalidValue`] for any other value.
    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().as_str() {
            "light" => Ok(Self::Light),
            "dark" => Ok(Self::Dark),
            _ => Err(RdeError::InvalidValue(format!(
                "color scheme '{value}' must be 'light' or 'dark'"
            ))),
        }
    }
}

/// Validated identifier of an installed theme.
///
/// The identifier doubles as the directory name below `themes/`, therefore it is
/// restricted to ASCII alphanumerics, `-`, `_`, and `.`, must start with an
/// alphanumeric character, and is limited to [`MAX_THEME_ID_LEN`] bytes. That
/// rules out path separators, hidden directories, and `..` traversal by
/// construction.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ThemeId(String);

impl ThemeId {
    /// Validates and wraps a theme identifier.
    ///
    /// # Parameters
    /// - `value`: candidate identifier; surrounding whitespace is trimmed
    ///
    /// # Returns
    /// The validated identifier.
    ///
    /// # Errors
    /// Returns [`RdeError::InvalidValue`] when the value is empty, too long,
    /// starts with a non-alphanumeric character, or contains unsupported
    /// characters.
    pub fn new(value: impl Into<String>) -> RdeResult<Self> {
        let candidate = value.into();
        let trimmed = candidate.trim();

        // Step 1: Reject empty and oversized identifiers.
        if trimmed.is_empty() {
            return Err(RdeError::InvalidValue(
                "theme name must not be empty".to_string(),
            ));
        }
        if trimmed.len() > MAX_THEME_ID_LEN {
            return Err(RdeError::InvalidValue(format!(
                "theme name must be at most {MAX_THEME_ID_LEN} characters"
            )));
        }

        // Step 2: Require a leading alphanumeric so no directory can be hidden
        // or addressed relatively (".", "..", "-rf").
        let mut characters = trimmed.chars();
        match characters.next() {
            Some(first) if first.is_ascii_alphanumeric() => {}
            _ => {
                return Err(RdeError::InvalidValue(format!(
                    "theme name '{trimmed}' must start with an alphanumeric character"
                )));
            }
        }

        // Step 3: Restrict the remaining characters to a filesystem-safe set.
        if !characters.all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.')
        }) {
            return Err(RdeError::InvalidValue(format!(
                "theme name '{trimmed}' may only contain letters, digits, '-', '_' and '.'"
            )));
        }

        Ok(Self(trimmed.to_string()))
    }

    /// Returns the identifier as a string slice.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for ThemeId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

impl AsRef<str> for ThemeId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

impl FromStr for ThemeId {
    type Err = RdeError;

    /// Validates a theme identifier, using the same rules as [`ThemeId::new`].
    fn from_str(value: &str) -> Result<Self, Self::Err> {
        Self::new(value)
    }
}

/// Manifest describing a single installed theme.
///
/// This is the content of `themes/<id>/theme.toml`. It is the authoritative
/// definition of the theme; the registry only records which manifests are
/// active or installed.
///
/// # Fields
/// - `schema_version`: manifest format version
/// - `name`: theme identifier, always equal to the containing directory name
/// - `display_name`: human-readable name for pickers and settings UIs
/// - `description`: short explanation of the theme
/// - `author`: optional creator or maintainer
/// - `license`: optional license identifier
/// - `version`: optional semantic version of the theme definition
/// - `source_color`: seed color (`#RRGGBB`) used to derive every palette
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ThemeManifest {
    /// Manifest format version.
    pub schema_version: u32,

    /// Validated theme identifier (directory name).
    pub name: ThemeId,

    /// Human-readable theme name.
    pub display_name: String,

    /// Short description shown in theme pickers.
    pub description: String,

    /// Optional theme creator or maintainer.
    #[serde(default)]
    pub author: Option<String>,

    /// Optional license identifier (e.g. `MIT`).
    #[serde(default)]
    pub license: Option<String>,

    /// Version of the theme definition.
    pub version: String,

    /// Normalized `#RRGGBB` seed color.
    pub source_color: String,
}

impl ThemeManifest {
    /// Creates a manifest for a new theme from its identifier and source color.
    ///
    /// # Parameters
    /// - `name`: validated theme identifier
    /// - `source_color`: seed color in any supported hexadecimal form
    ///
    /// # Returns
    /// A manifest with a generated display name and description.
    ///
    /// # Errors
    /// Returns [`RdeError::InvalidValue`] when the source color cannot be
    /// parsed.
    pub fn new(name: ThemeId, source_color: &str) -> RdeResult<Self> {
        let source_color = normalize_hex_color(source_color)?;

        Ok(Self {
            schema_version: MANIFEST_SCHEMA_VERSION,
            display_name: name.as_str().to_string(),
            description: format!("RDE theme generated from the source color {source_color}."),
            author: None,
            license: None,
            version: DEFAULT_THEME_VERSION.to_string(),
            source_color,
            name,
        })
    }

    /// Builds the manifest of the built-in default theme.
    ///
    /// # Errors
    /// Returns [`RdeError::InvalidValue`] only if the shipped constant values
    /// were edited into an invalid state.
    pub fn default_theme() -> RdeResult<Self> {
        let mut manifest = Self::new(ThemeId::new(DEFAULT_THEME_ID)?, DEFAULT_THEME_SOURCE_COLOR)?;
        manifest.display_name = DEFAULT_THEME_DISPLAY_NAME.to_string();
        manifest.description = DEFAULT_THEME_DESCRIPTION.to_string();
        Ok(manifest)
    }
}

/// A manifest resolved into a concrete palette for one color scheme.
///
/// This is what the D-Bus API and any future toolkit writers consume: the
/// definition of the theme plus the colors that should currently be applied.
///
/// # Fields
/// - `manifest`: theme definition
/// - `color_scheme`: scheme the palette was generated for
/// - `palette`: semantic color roles
#[derive(Debug, Clone, PartialEq)]
pub struct Theme {
    /// Theme definition loaded from the manifest.
    pub manifest: ThemeManifest,

    /// Scheme used to generate the palette.
    pub color_scheme: ColorScheme,

    /// Semantic color roles for this scheme.
    pub palette: Palette,
}

impl Theme {
    /// Returns the palette as a role-name to `#RRGGBB` map.
    pub fn role_map(&self) -> std::collections::BTreeMap<String, String> {
        self.palette.role_map()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn color_scheme_round_trips_through_text() {
        for scheme in [ColorScheme::Light, ColorScheme::Dark] {
            assert_eq!(
                scheme
                    .as_str()
                    .parse::<ColorScheme>()
                    .expect("valid scheme"),
                scheme
            );
            assert_eq!(scheme.toggled().toggled(), scheme);
            assert_eq!(scheme.is_dark(), scheme == ColorScheme::Dark);
        }

        assert!("sepia".parse::<ColorScheme>().is_err());
        assert_eq!(
            " DARK ".parse::<ColorScheme>().expect("scheme is trimmed"),
            ColorScheme::Dark
        );
    }

    #[test]
    fn theme_id_accepts_safe_identifiers() {
        for candidate in ["default", "ocean-blue", "Ocean_2", "v1.2"] {
            assert!(
                ThemeId::new(candidate).is_ok(),
                "'{candidate}' must be a valid theme id"
            );
        }
        assert_eq!(
            ThemeId::new("  ocean  ").expect("trimmed id").as_str(),
            "ocean"
        );
    }

    #[test]
    fn theme_id_rejects_path_traversal_and_bad_characters() {
        for candidate in [
            "",
            "   ",
            "..",
            "../escape",
            "/absolute",
            ".hidden",
            "-flag",
            "with space",
            "naïve",
            &"x".repeat(MAX_THEME_ID_LEN + 1),
        ] {
            assert!(
                ThemeId::new(candidate).is_err(),
                "'{candidate}' must be rejected as a theme id"
            );
        }
    }

    #[test]
    fn new_manifest_normalizes_the_source_color() {
        let manifest = ThemeManifest::new(ThemeId::new("ocean").expect("valid id"), "6dd6da")
            .expect("valid color");

        assert_eq!(manifest.source_color, "#6DD6DA");
        assert_eq!(manifest.display_name, "ocean");
        assert_eq!(manifest.schema_version, MANIFEST_SCHEMA_VERSION);
    }

    #[test]
    fn manifest_rejects_invalid_source_colors() {
        let id = ThemeId::new("ocean").expect("valid id");
        assert!(ThemeManifest::new(id, "#12345").is_err());
    }

    #[test]
    fn default_manifest_uses_the_shipped_seed() {
        let manifest = ThemeManifest::default_theme().expect("default manifest");

        assert_eq!(manifest.name.as_str(), DEFAULT_THEME_ID);
        assert_eq!(manifest.source_color, DEFAULT_THEME_SOURCE_COLOR);
        assert_eq!(manifest.display_name, DEFAULT_THEME_DISPLAY_NAME);
    }
}
