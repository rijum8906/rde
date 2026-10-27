//! # Theme Database Paths
//!
//! Resolves XDG base directories and paths for themes, settings, and cache files.

use std::{
    env,
    path::{Path, PathBuf},
};

/// File name of the published resolved theme cache.
///
/// Applications read this file before the session bus is ready, so both this
/// service and its clients depend on the name staying stable.
pub const DEFAULT_PUBLISHED_THEME_FILE: &str = "default_theme.json";

/// Resolves `$XDG_DATA_HOME`, falling back to `~/.local/share`.
#[must_use]
pub fn xdg_data_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_DATA_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".local").join("share")
}

/// Resolves `$XDG_CONFIG_HOME`, falling back to `~/.config`.
#[must_use]
pub fn xdg_config_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_CONFIG_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".config")
}

/// Resolves `$XDG_CACHE_HOME`, falling back to `~/.cache`.
#[must_use]
pub fn xdg_cache_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_CACHE_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".cache")
}

/// Paths configuration for theme data, settings, and cache files.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThemePaths {
    data_themes_dir: PathBuf,
    config_themes_dir: PathBuf,
    cache_theme_dir: PathBuf,
    system_themes_dir: PathBuf,
    published_theme_file: PathBuf,
}

impl Default for ThemePaths {
    fn default() -> Self {
        Self::resolve()
    }
}

impl ThemePaths {
    /// Resolves default paths using standard XDG base environment variables.
    #[must_use]
    pub fn resolve() -> Self {
        Self {
            data_themes_dir: xdg_data_home().join("rde").join("themes"),
            config_themes_dir: xdg_config_home().join("rde").join("themes"),
            cache_theme_dir: xdg_cache_home().join("rde").join("theme"),
            system_themes_dir: PathBuf::from("/usr/share/rde/themes"),
            published_theme_file: xdg_data_home()
                .join("rde")
                .join("rde-theme")
                .join(DEFAULT_PUBLISHED_THEME_FILE),
        }
    }

    /// Constructs custom paths for testing or isolated environments.
    #[must_use]
    pub fn custom(
        data_themes_dir: PathBuf,
        config_themes_dir: PathBuf,
        cache_theme_dir: PathBuf,
        system_themes_dir: PathBuf,
        published_theme_file: PathBuf,
    ) -> Self {
        Self {
            data_themes_dir,
            config_themes_dir,
            cache_theme_dir,
            system_themes_dir,
            published_theme_file,
        }
    }

    /// User themes directory containing installed themes and `themes.toml`.
    #[must_use]
    pub fn data_themes_dir(&self) -> &Path {
        &self.data_themes_dir
    }

    /// User configuration directory containing `settings.toml`.
    #[must_use]
    pub fn config_themes_dir(&self) -> &Path {
        &self.config_themes_dir
    }

    /// Cache directory holding `current.json` and generated stylesheets.
    #[must_use]
    pub fn cache_theme_dir(&self) -> &Path {
        &self.cache_theme_dir
    }

    /// System-wide read-only themes directory (`/usr/share/rde/themes`).
    #[must_use]
    pub fn system_themes_dir(&self) -> &Path {
        &self.system_themes_dir
    }

    /// Path to the factual `themes.toml` registry file.
    #[must_use]
    pub fn registry_file(&self) -> PathBuf {
        self.data_themes_dir.join("themes.toml")
    }

    /// Path to the user preference `settings.toml` file.
    #[must_use]
    pub fn settings_file(&self) -> PathBuf {
        self.config_themes_dir.join("settings.toml")
    }

    /// Path to the published resolved theme cache consumed at application startup.
    ///
    /// Defaults to `$XDG_DATA_HOME/rde/rde-theme/default_theme.json` and is
    /// rewritten atomically before every `ThemeChanged` signal.
    #[must_use]
    pub fn published_theme_file(&self) -> PathBuf {
        self.published_theme_file.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn published_theme_file_lives_under_the_rde_data_directory() {
        let paths = ThemePaths::resolve();
        let expected = xdg_data_home()
            .join("rde")
            .join("rde-theme")
            .join(DEFAULT_PUBLISHED_THEME_FILE);

        assert_eq!(paths.published_theme_file(), expected);
        assert_eq!(
            paths
                .published_theme_file()
                .file_name()
                .and_then(|name| name.to_str()),
            Some("default_theme.json")
        );
    }
}
