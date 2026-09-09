//! # Theme Configuration & Metadata Models
//!
//! Defines core data structures for theme management, including metadata,
//! color scheme preferences, dynamic configuration, and theme composition.
//!
//! ## Related
//! - [`crate::domain::material::MaterialColorPalette`]
//! - [`crate::domain::gtk::GtkColorPalette`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use serde::{Deserialize, Serialize};
use zbus::zvariant::{Optional, Type, Value};

use crate::domain::gtk::GtkColorPalette;
use crate::domain::material::MaterialColorPalette;

/// Metadata describing a theme package.
///
/// Contains human-readable information about a theme's origin, versioning, and licensing.
///
/// # Fields
/// - `version`: Semantic version string (e.g., "1.0.0")
/// - `name`: Human-readable theme name
/// - `description`: Long-form description of the theme
/// - `author`: Theme creator (optional)
/// - `license`: License identifier (optional)
#[derive(Type, Serialize, Deserialize, Clone, Debug)]
pub struct ThemeMetadata {
    /// Version identifier (e.g., "1.0.0" or "0.0.1")
    pub version: String,
    /// Human-readable theme name
    pub name: String,
    /// Long description of theme purpose and appearance
    pub description: String,
    /// Theme creator or maintainer (optional)
    pub author: Optional<String>,
    /// License identifier (optional, e.g., "MIT", "GPL-3.0")
    pub license: Optional<String>,
}

impl Default for ThemeMetadata {
    fn default() -> Self {
        Self {
            version: String::from("0.0.1"),
            name: String::from("RDE Theme"),
            description: String::from("A theme for RDE"),
            author: Optional::from(Some(String::from("RDE"))),
            license: Optional::from(Some(String::from("MIT"))),
        }
    }
}

/// System-wide color scheme preference.
///
/// Represents the user's preference for light/dark mode theming.
/// This is exposed via Freedesktop Portal (`org.freedesktop.portal.Settings`)
/// for compatibility with standard desktop environments.
#[derive(Type, Default, Serialize, Deserialize, Clone, Debug, Value)]
pub enum ColorScheme {
    /// No preference specified; system may choose based on time of day
    NoPreference,
    /// Prefer light color scheme
    #[default]
    PreferLight,
    /// Prefer dark color scheme
    PreferDark,
}

/// Configuration for dynamic theme generation.
///
/// Controls whether the theme is statically defined or dynamically generated
/// from a seed color (e.g., dominant wallpaper color).
///
/// # Fields
/// - `is_dynamic`: If true, theme is generated from seed; if false, theme is static
/// - `seed`: Base color for dynamic palette generation (hex string, e.g., "#6DD6DA")
#[derive(Type, Serialize, Deserialize, PartialEq, Clone, Debug)]
pub struct DynamicConfig {
    /// Whether the theme palette is dynamically generated from seed color
    pub is_dynamic: bool,
    /// Seed color for dynamic palette generation (hex string, e.g., "#6DD6DA")
    pub seed: Optional<String>,
}

impl Default for DynamicConfig {
    fn default() -> Self {
        Self {
            is_dynamic: false,
            seed: Optional::from(Some(String::from("#6DD6DA"))),
        }
    }
}

/// Complete theme configuration composing metadata, color palettes, and preferences.
///
/// Represents a full theme package that can be serialized/deserialized over D-Bus
/// and includes all necessary information for applying a coherent visual appearance
/// across the desktop environment.
///
/// # Fields
/// - `metadata`: Theme package information
/// - `color_scheme`: User's light/dark mode preference
/// - `dynamic_config`: Dynamic generation settings
/// - `material_palette`: Material 3 color palette (optional if static theme)
/// - `gtk_palette`: GTK-specific color mappings (optional)
#[derive(Type, Serialize, Deserialize, Clone, Debug)]
pub struct Theme {
    /// Theme package metadata (name, author, version, etc.)
    pub metadata: ThemeMetadata,

    /// User's color scheme preference (light/dark mode)
    pub color_scheme: ColorScheme,

    /// Dynamic generation configuration (seed color, etc.)
    pub dynamic_config: Optional<DynamicConfig>,

    /// Material 3 color palette with all semantic roles
    pub material_palette: Optional<MaterialColorPalette>,

    /// GTK-specific color palette mappings
    pub gtk_palette: Optional<GtkColorPalette>,
}

impl Default for Theme {
    fn default() -> Self {
        Self {
            metadata: ThemeMetadata::default(),
            color_scheme: ColorScheme::NoPreference,
            dynamic_config: Optional::default(),
            material_palette: Optional::default(),
            gtk_palette: Optional::default(),
        }
    }
}
