//! # Theme Registry (`themes.toml`)
//!
//! Models the session state stored in `$XDG_DATA_HOME/rde/rde-theme/themes.toml`:
//! which theme is active, which appearance the user prefers, and which themes
//! are installed.
//!
//! ## Example
//! ```toml
//! schema_version = 1
//! current_theme = "default"
//! color_scheme = "dark"
//! installed = ["default", "ocean"]
//! ```
//!
//! ## Design Notes
//! - The registry never stores palette values; they are derived from each
//!   theme's manifest so a source color change cannot desynchronize the two.
//! - The installed list is advisory. [`crate::theme_store::ThemeStore`]
//!   reconciles it against the manifests found on disk at startup, which makes
//!   the file self-healing after manual edits or interrupted writes.
//!
//! ## Related
//! - [`crate::domain::theme::ThemeId`][]: validated theme identifier
//! - [`crate::domain::theme::ColorScheme`][]: light/dark preference
//! - [`crate::theme_store`][]: load, reconcile, and persist operations
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

use crate::{
    constants::REGISTRY_SCHEMA_VERSION,
    domain::theme::{ColorScheme, ThemeId},
};

/// Content of the `themes.toml` registry.
///
/// # Fields
/// - `schema_version`: registry format version
/// - `current_theme`: active theme, absent only for an uninitialized database
/// - `color_scheme`: active light/dark appearance
/// - `installed`: identifiers of the installed themes
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemeRegistry {
    /// Registry format version.
    pub schema_version: u32,

    /// Identifier of the active theme.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_theme: Option<ThemeId>,

    /// Active light/dark appearance.
    pub color_scheme: ColorScheme,

    /// Identifiers of the installed themes, sorted for stable output.
    #[serde(default)]
    pub installed: Vec<ThemeId>,
}

impl Default for ThemeRegistry {
    fn default() -> Self {
        Self {
            schema_version: REGISTRY_SCHEMA_VERSION,
            current_theme: None,
            color_scheme: ColorScheme::default(),
            installed: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_round_trips_through_toml() {
        let registry = ThemeRegistry {
            schema_version: REGISTRY_SCHEMA_VERSION,
            current_theme: Some(ThemeId::new("ocean").expect("valid id")),
            color_scheme: ColorScheme::Dark,
            installed: vec![
                ThemeId::new("default").expect("valid id"),
                ThemeId::new("ocean").expect("valid id"),
            ],
        };

        let encoded = toml::to_string_pretty(&registry).expect("serialize registry");
        assert!(encoded.contains("current_theme = \"ocean\""));
        assert!(encoded.contains("color_scheme = \"dark\""));

        let decoded: ThemeRegistry = toml::from_str(&encoded).expect("deserialize registry");
        assert_eq!(decoded, registry);
    }

    #[test]
    fn absent_current_theme_is_not_serialized() {
        let registry = ThemeRegistry::default();
        let encoded = toml::to_string_pretty(&registry).expect("serialize registry");

        assert!(!encoded.contains("current_theme"));
    }
}
