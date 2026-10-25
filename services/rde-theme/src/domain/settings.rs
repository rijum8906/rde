//! # User-Owned Theme Settings
//!
//! Models `settings.toml` storing user preferences for theme selection, mode,
//! and contrast.
//!
//! This file is user-owned, hand-editing is supported, it survives registry
//! rebuilds, and it is the only file whose loss changes the user's appearance.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use thiserror::Error;
use tracing::warn;

use crate::domain::{
    identity::ThemeId,
    manifest::{ContrastLevel, ThemeMode},
    registry::ThemeRegistry,
    resolved::Color,
};

/// Supported schema version for `settings.toml`.
pub const SUPPORTED_SETTINGS_SCHEMA_VERSION: u32 = 1;

/// Errors produced when validating theme settings.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum SettingsError {
    /// Schema version is unsupported.
    #[error("unsupported settings schema version {found}, expected {supported}")]
    UnsupportedSchemaVersion { found: u32, supported: u32 },

    /// Fixed seed color could not be parsed as a valid `#RRGGBB` color.
    #[error("invalid fixed seed color '{0}'")]
    InvalidFixedSeed(String),

    /// `SeedSource::Fixed` was selected without any seed color to derive from.
    #[error("seed source 'fixed' requires a '#RRGGBB' seed color")]
    MissingFixedSeed,

    /// Wallpaper path is relative, so it cannot be resolved reliably.
    #[error("wallpaper path '{0}' must be absolute")]
    WallpaperNotAbsolute(PathBuf),
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

    /// Settings specifically configuring the dynamic wallpaper theme.
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
    /// Returns [`SettingsError`] if schema version is unsupported or fixed seed
    /// color is invalid. A dangling `active_theme` is logged with a warning and
    /// treated as `None` rather than causing an error.
    pub fn validate(&self, registry: &ThemeRegistry) -> Result<(), SettingsError> {
        // Step 1: Verify schema version.
        if self.schema_version != SUPPORTED_SETTINGS_SCHEMA_VERSION {
            return Err(SettingsError::UnsupportedSchemaVersion {
                found: self.schema_version,
                supported: SUPPORTED_SETTINGS_SCHEMA_VERSION,
            });
        }

        // Step 2: Validate fixed seed if provided.
        if let Some(seed) = &self.dynamic.fixed_seed {
            Color::new(seed).map_err(|e| SettingsError::InvalidFixedSeed(e.to_string()))?;
        }

        // Step 3: Wallpaper paths must be absolute when recorded.
        if let Some(wallpaper) = &self.dynamic.wallpaper {
            if !wallpaper.is_absolute() {
                return Err(SettingsError::WallpaperNotAbsolute(wallpaper.clone()));
            }
        }

        // Step 4: Validate active_theme reference.
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

/// Dynamic theme configuration.
///
/// This stores inputs only (never resolved colors) to prevent state from
/// desynchronizing when wallpapers change.
#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DynamicSettings {
    /// Source for seed color generation.
    #[serde(default)]
    pub seed_source: SeedSource,

    /// Explicit hex seed color `#RRGGBB` used when `seed_source == SeedSource::Fixed`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fixed_seed: Option<String>,

    /// Absolute path of the wallpaper the seed color is derived from, when known.
    ///
    /// Persisted so wallpaper-derived colors survive a daemon restart instead of
    /// silently reverting to the neutral fallback seed.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wallpaper: Option<PathBuf>,
}

/// Partial update of the built-in dynamic theme inputs.
///
/// Every field is optional so callers can change a single input; `None` keeps the
/// currently persisted value.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DynamicThemeUpdate {
    /// Seed source to select, leaving the current one unchanged when `None`.
    pub seed_source: Option<SeedSource>,

    /// Explicit `#RRGGBB` seed color to store, leaving the current one unchanged when `None`.
    pub fixed_seed: Option<String>,

    /// Absolute wallpaper path to derive the seed color from, unchanged when `None`.
    pub wallpaper: Option<PathBuf>,
}

impl DynamicThemeUpdate {
    /// Applies the requested inputs to `settings`.
    ///
    /// The update is all-or-nothing: every provided input is validated before
    /// `settings` is touched, so a rejected update leaves it unchanged.
    ///
    /// # Parameters
    /// - `settings`: settings to mutate in place
    ///
    /// # Errors
    /// Returns [`SettingsError::InvalidFixedSeed`] for malformed seed colors,
    /// [`SettingsError::WallpaperNotAbsolute`] for relative wallpaper paths, and
    /// [`SettingsError::MissingFixedSeed`] when `fixed` is selected without a seed.
    pub fn apply(&self, settings: &mut ThemeSettings) -> Result<(), SettingsError> {
        // Step 1: Validate every provided input before mutating anything.
        if let Some(seed) = &self.fixed_seed {
            Color::new(seed).map_err(|err| SettingsError::InvalidFixedSeed(err.to_string()))?;
        }

        if let Some(wallpaper) = &self.wallpaper {
            if !wallpaper.is_absolute() {
                return Err(SettingsError::WallpaperNotAbsolute(wallpaper.clone()));
            }
        }

        // Step 2: Resolve the effective seed source and seed color.
        let next_source = self.seed_source.unwrap_or(settings.dynamic.seed_source);
        let next_seed = self
            .fixed_seed
            .clone()
            .or_else(|| settings.dynamic.fixed_seed.clone());

        if next_source == SeedSource::Fixed && next_seed.is_none() {
            return Err(SettingsError::MissingFixedSeed);
        }

        // Step 3: Commit the validated inputs.
        settings.dynamic.seed_source = next_source;
        settings.dynamic.fixed_seed = next_seed;
        if let Some(wallpaper) = &self.wallpaper {
            settings.dynamic.wallpaper = Some(wallpaper.clone());
        }

        Ok(())
    }
}

/// Source used to derive the seed color for dynamic themes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum SeedSource {
    /// Derive color dynamically from current desktop wallpaper.
    #[default]
    Wallpaper,

    /// Use a static user-specified seed color.
    Fixed,
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
    fn test_invalid_fixed_seed_fails_validation() {
        let registry = ThemeRegistry::new();
        let settings = ThemeSettings {
            schema_version: 1,
            active_theme: None,
            mode: ThemeMode::Dark,
            contrast: ContrastLevel::Normal,
            dynamic: DynamicSettings {
                seed_source: SeedSource::Fixed,
                fixed_seed: Some("not-a-color".into()),
                wallpaper: None,
            },
        };

        assert!(matches!(
            settings.validate(&registry),
            Err(SettingsError::InvalidFixedSeed(_))
        ));
    }

    #[test]
    fn test_dynamic_update_applies_seed_source() {
        let mut settings = ThemeSettings::default();

        let update = DynamicThemeUpdate {
            seed_source: Some(SeedSource::Fixed),
            fixed_seed: Some("#006a6a".into()),
            wallpaper: Some(PathBuf::from("/home/user/wallpaper.png")),
        };

        update.apply(&mut settings).unwrap();
        assert_eq!(settings.dynamic.seed_source, SeedSource::Fixed);
        assert_eq!(settings.dynamic.fixed_seed.as_deref(), Some("#006a6a"));
        assert_eq!(
            settings.dynamic.wallpaper,
            Some(PathBuf::from("/home/user/wallpaper.png"))
        );
    }

    #[test]
    fn test_dynamic_update_rejects_invalid_inputs_without_mutating() {
        let mut settings = ThemeSettings::default();
        let original = settings.clone();

        // Malformed seed color.
        let invalid_seed = DynamicThemeUpdate {
            seed_source: Some(SeedSource::Fixed),
            fixed_seed: Some("teal".into()),
            wallpaper: None,
        };
        assert!(matches!(
            invalid_seed.apply(&mut settings),
            Err(SettingsError::InvalidFixedSeed(_))
        ));

        // Relative wallpaper path.
        let relative_wallpaper = DynamicThemeUpdate {
            seed_source: Some(SeedSource::Wallpaper),
            fixed_seed: None,
            wallpaper: Some(PathBuf::from("wallpaper.png")),
        };
        assert!(matches!(
            relative_wallpaper.apply(&mut settings),
            Err(SettingsError::WallpaperNotAbsolute(_))
        ));

        // Switching to `fixed` without any seed color.
        let missing_seed = DynamicThemeUpdate {
            seed_source: Some(SeedSource::Fixed),
            fixed_seed: None,
            wallpaper: None,
        };
        assert_eq!(
            missing_seed.apply(&mut settings),
            Err(SettingsError::MissingFixedSeed)
        );

        assert_eq!(settings, original);
    }
}
