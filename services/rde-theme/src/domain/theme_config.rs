//! # Theme Registry (`themes.toml`)
//!
//! Models the session state in `themes.toml`: the active theme, the color scheme,
//! and the installed themes.

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
