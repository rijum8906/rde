//! # User-Owned Theme Settings
//!
//! Models `settings.toml` storing user preferences for theme selection, mode,
//! and contrast.
//!
//! This file is user-owned, hand-editing is supported, it survives registry
//! rebuilds, and it is the only file whose loss changes the user's appearance.

use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::warn;

use crate::domain::{
    identity::ThemeId,
    manifest::{ContrastLevel, ThemeMode},
    registry::ThemeRegistry,
    resolved::{Color, ColorSeeds, DEFAULT_ERROR_SEED, FALLBACK_SEED_COLOR},
};

/// Supported schema version for `settings.toml`.
pub const SUPPORTED_SETTINGS_SCHEMA_VERSION: u32 = 1;

/// Errors produced when validating theme settings.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum SettingsError {
    /// Schema version is unsupported.
    #[error("unsupported settings schema version {found}, expected {supported}")]
    UnsupportedSchemaVersion { found: u32, supported: u32 },

    /// One of the dynamic seed colors is not a valid `#RRGGBB` value.
    #[error("invalid {role} seed color '{value}'")]
    InvalidSeedColor {
        /// Role whose seed failed validation.
        role: &'static str,
        /// Rejected value.
        value: String,
    },
}

/// User appearance settings persisted in `settings.toml`.
///
/// Invariant:
/// This file is user-owned, hand-editing is supported, it survives registry
/// rebuilds, and it is the only file whose loss changes the user's appearance.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemeSettings {
    /// Schema version for the settings file format.
    pub schema_version: u32,

    /// Selected theme identifier. `None` selects the built-in dynamic theme.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub active_theme: Option<ThemeId>,

    /// Appearance scheme preference (Light or Dark).
    #[serde(default)]
    pub mode: ThemeMode,

    /// Contrast requirement (Normal, Medium, or High).
    #[serde(default)]
    pub contrast: ContrastLevel,

    /// Seed colors of the built-in dynamic theme.
    #[serde(default)]
    pub dynamic: DynamicSettings,
}

impl Default for ThemeSettings {
    fn default() -> Self {
        Self {
            schema_version: SUPPORTED_SETTINGS_SCHEMA_VERSION,
            active_theme: None,
            mode: ThemeMode::Dark,
            contrast: ContrastLevel::Normal,
            dynamic: DynamicSettings::default(),
        }
    }
}

impl ThemeSettings {
    /// Constructs a new [`ThemeSettings`] with default preferences.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Validates the settings against the installed themes in the registry.
    ///
    /// # Errors
    /// Returns [`SettingsError`] if the schema version is unsupported or one of
    /// the dynamic seed colors is invalid. A dangling `active_theme` is logged
    /// with a warning and treated as `None` rather than causing an error.
    pub fn validate(&self, registry: &ThemeRegistry) -> Result<(), SettingsError> {
        // Step 1: Verify schema version.
        if self.schema_version != SUPPORTED_SETTINGS_SCHEMA_VERSION {
            return Err(SettingsError::UnsupportedSchemaVersion {
                found: self.schema_version,
                supported: SUPPORTED_SETTINGS_SCHEMA_VERSION,
            });
        }

        // Step 2: Validate every dynamic seed color.
        for (role, value) in self.dynamic.entries() {
            Color::new(value).map_err(|_| SettingsError::InvalidSeedColor {
                role,
                value: value.to_string(),
            })?;
        }

        // Step 3: Validate active_theme reference.
        if let Some(active_id) = &self.active_theme {
            let is_known = active_id.is_builtin() || registry.themes.contains_key(active_id);
            if !is_known {
                warn!(theme = %active_id, "Active theme is not installed in registry; falling back to dynamic default");
            }
        }

        Ok(())
    }

    /// Sanitizes the in-memory settings by resetting dangling `active_theme` to `None`.
    pub fn sanitize_active_theme(&mut self, registry: &ThemeRegistry) {
        if let Some(active_id) = &self.active_theme {
            let is_known = active_id.is_builtin() || registry.themes.contains_key(active_id);
            if !is_known {
                self.active_theme = None;
            }
        }
    }
}

/// Seed colors of the built-in dynamic theme.
///
/// This stores inputs only (never resolved colors), one `#RRGGBB` seed per role
/// family. Every palette is regenerated from these seeds, so the file stays the
/// single source of truth for the dynamic theme.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DynamicSettings {
    /// Seed of the primary family and of the neutral surfaces.
    #[serde(default = "default_neutral_seed")]
    pub primary: String,

    /// Seed of the secondary family.
    #[serde(default = "default_neutral_seed")]
    pub secondary: String,

    /// Seed of the tertiary family.
    #[serde(default = "default_neutral_seed")]
    pub tertiary: String,

    /// Seed of the error family.
    #[serde(default = "default_error_seed")]
    pub error: String,
}

impl Default for DynamicSettings {
    fn default() -> Self {
        Self {
            primary: default_neutral_seed(),
            secondary: default_neutral_seed(),
            tertiary: default_neutral_seed(),
            error: default_error_seed(),
        }
    }
}

impl DynamicSettings {
    /// Returns every seed with the role name used in logs and validation errors.
    #[must_use]
    pub fn entries(&self) -> [(&'static str, &str); 4] {
        [
            ("primary", &self.primary),
            ("secondary", &self.secondary),
            ("tertiary", &self.tertiary),
            ("error", &self.error),
        ]
    }

    /// Parses the persisted seeds into the four colors the palette is computed from.
    ///
    /// A malformed value falls back per role instead of failing the whole theme,
    /// so a hand-edited `settings.toml` can never leave the desktop unthemed.
    #[must_use]
    pub fn color_seeds(&self) -> ColorSeeds {
        ColorSeeds {
            primary: parse_seed("primary", &self.primary, FALLBACK_SEED_COLOR),
            secondary: parse_seed("secondary", &self.secondary, FALLBACK_SEED_COLOR),
            tertiary: parse_seed("tertiary", &self.tertiary, FALLBACK_SEED_COLOR),
            error: parse_seed("error", &self.error, DEFAULT_ERROR_SEED),
        }
    }
}

/// Default neutral seed shared by the primary, secondary, and tertiary families.
fn default_neutral_seed() -> String {
    FALLBACK_SEED_COLOR.to_string()
}

/// Default error seed.
fn default_error_seed() -> String {
    DEFAULT_ERROR_SEED.to_string()
}

/// Parses one persisted seed, logging and falling back when it is malformed.
fn parse_seed(role: &'static str, value: &str, fallback: &str) -> Color {
    match Color::new(value) {
        Ok(color) => color,
        Err(err) => {
            warn!(role, value, error = %err, "Invalid dynamic seed color; using the fallback seed");
            Color::new(fallback).unwrap_or_else(|_| Color::fallback())
        }
    }
}

/// Partial update of the built-in dynamic theme seeds.
///
/// Every field is optional so callers can change a single seed; `None` keeps the
/// currently persisted value.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DynamicThemeUpdate {
    /// Primary seed to store, leaving the current one unchanged when `None`.
    pub primary: Option<String>,

    /// Secondary seed to store, leaving the current one unchanged when `None`.
    pub secondary: Option<String>,

    /// Tertiary seed to store, leaving the current one unchanged when `None`.
    pub tertiary: Option<String>,

    /// Error seed to store, leaving the current one unchanged when `None`.
    pub error: Option<String>,
}

impl DynamicThemeUpdate {
    /// Applies the requested seeds to `settings`.
    ///
    /// The update is all-or-nothing: every provided seed is validated before
    /// `settings` is touched, so a rejected update leaves it unchanged.
    ///
    /// # Parameters
    /// - `settings`: settings to mutate in place
    ///
    /// # Errors
    /// Returns [`SettingsError::InvalidSeedColor`] for a malformed seed. The
    /// error names the role so callers can point at the offending control.
    pub fn apply(&self, settings: &mut ThemeSettings) -> Result<(), SettingsError> {
        // Step 1: Validate every provided seed before mutating anything.
        for (role, value) in [
            ("primary", &self.primary),
            ("secondary", &self.secondary),
            ("tertiary", &self.tertiary),
            ("error", &self.error),
        ] {
            if let Some(value) = value {
                Color::new(value).map_err(|_| SettingsError::InvalidSeedColor {
                    role,
                    value: value.clone(),
                })?;
            }
        }

        // Step 2: Commit the validated seeds, keeping untouched roles as they are.
        if let Some(primary) = &self.primary {
            settings.dynamic.primary = primary.clone();
        }
        if let Some(secondary) = &self.secondary {
            settings.dynamic.secondary = secondary.clone();
        }
        if let Some(tertiary) = &self.tertiary {
            settings.dynamic.tertiary = tertiary.clone();
        }
        if let Some(error) = &self.error {
            settings.dynamic.error = error.clone();
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dangling_active_theme_yields_none_with_warning() {
        let registry = ThemeRegistry::new(); // Empty registry
        let mut settings = ThemeSettings {
            schema_version: 1,
            active_theme: Some(ThemeId::new("deleted-theme").unwrap()),
            mode: ThemeMode::Dark,
            contrast: ContrastLevel::Normal,
            dynamic: DynamicSettings::default(),
        };

        // Validation does not return error
        assert!(settings.validate(&registry).is_ok());

        // Sanitizing clears the dangling reference
        settings.sanitize_active_theme(&registry);
        assert_eq!(settings.active_theme, None);
    }

    #[test]
    fn test_valid_active_theme_or_builtin_preserved() {
        let mut registry = ThemeRegistry::new();
        let id = ThemeId::new("catppuccin").unwrap();
        registry.themes.insert(id.clone(), Default::default());

        let mut settings = ThemeSettings {
            schema_version: 1,
            active_theme: Some(id.clone()),
            mode: ThemeMode::Dark,
            contrast: ContrastLevel::Normal,
            dynamic: DynamicSettings::default(),
        };

        assert!(settings.validate(&registry).is_ok());
        settings.sanitize_active_theme(&registry);
        assert_eq!(settings.active_theme, Some(id));

        // Built-in dynamic theme also preserved
        let mut dynamic_settings = ThemeSettings {
            active_theme: Some(ThemeId::builtin_dynamic()),
            ..settings
        };
        assert!(dynamic_settings.validate(&registry).is_ok());
        dynamic_settings.sanitize_active_theme(&registry);
        assert_eq!(
            dynamic_settings.active_theme,
            Some(ThemeId::builtin_dynamic())
        );
    }

    #[test]
    fn test_invalid_seed_color_fails_validation() {
        let registry = ThemeRegistry::new();
        let settings = ThemeSettings {
            schema_version: 1,
            active_theme: None,
            mode: ThemeMode::Dark,
            contrast: ContrastLevel::Normal,
            dynamic: DynamicSettings {
                primary: "not-a-color".into(),
                ..DynamicSettings::default()
            },
        };

        assert_eq!(
            settings.validate(&registry),
            Err(SettingsError::InvalidSeedColor {
                role: "primary",
                value: "not-a-color".into(),
            })
        );
    }

    #[test]
    fn test_default_seeds_are_the_neutral_blue_and_material_red() {
        let seeds = DynamicSettings::default().color_seeds();

        assert_eq!(seeds.primary.as_str(), FALLBACK_SEED_COLOR);
        assert_eq!(seeds.secondary.as_str(), FALLBACK_SEED_COLOR);
        assert_eq!(seeds.tertiary.as_str(), FALLBACK_SEED_COLOR);
        assert_eq!(seeds.error.as_str(), DEFAULT_ERROR_SEED);
    }

    #[test]
    fn test_dynamic_update_applies_every_seed() {
        let mut settings = ThemeSettings::default();

        let update = DynamicThemeUpdate {
            primary: Some("#006a6a".into()),
            secondary: Some("#6750a4".into()),
            tertiary: Some("#b52700".into()),
            error: Some("#b90063".into()),
        };

        update.apply(&mut settings).unwrap();
        assert_eq!(settings.dynamic.primary, "#006a6a");
        assert_eq!(settings.dynamic.secondary, "#6750a4");
        assert_eq!(settings.dynamic.tertiary, "#b52700");
        assert_eq!(settings.dynamic.error, "#b90063");
    }

    #[test]
    fn test_dynamic_update_keeps_untouched_seeds() {
        let mut settings = ThemeSettings::default();
        let original = settings.dynamic.clone();

        let update = DynamicThemeUpdate {
            primary: Some("#006a6a".into()),
            ..DynamicThemeUpdate::default()
        };

        update.apply(&mut settings).unwrap();
        assert_eq!(settings.dynamic.primary, "#006a6a");
        assert_eq!(settings.dynamic.secondary, original.secondary);
        assert_eq!(settings.dynamic.tertiary, original.tertiary);
        assert_eq!(settings.dynamic.error, original.error);
    }

    #[test]
    fn test_dynamic_update_rejects_invalid_inputs_without_mutating() {
        let mut settings = ThemeSettings::default();
        let original = settings.clone();

        let invalid_seed = DynamicThemeUpdate {
            primary: Some("teal".into()),
            ..DynamicThemeUpdate::default()
        };
        assert_eq!(
            invalid_seed.apply(&mut settings),
            Err(SettingsError::InvalidSeedColor {
                role: "primary",
                value: "teal".into(),
            })
        );

        // A later role is validated too, and the first four-role update is atomic.
        let invalid_error = DynamicThemeUpdate {
            primary: Some("#006a6a".into()),
            error: Some("rgba(1,2,3)".into()),
            ..DynamicThemeUpdate::default()
        };
        assert!(matches!(
            invalid_error.apply(&mut settings),
            Err(SettingsError::InvalidSeedColor { role: "error", .. })
        ));

        assert_eq!(settings, original);
    }
}
