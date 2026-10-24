//! # Theme Database Paths
//!
//! Resolves the XDG-compliant location of the theme database and derives the
//! path of every file and directory the service owns.
//!
//! ## Layout
//! ```text
//! $XDG_DATA_HOME/rde/rde-theme/          (defaults to ~/.local/share)
//! ├── themes.toml                        registry: active theme, scheme, installed list
//! └── themes/
//!     └── <theme-id>/
//!         └── theme.toml                 manifest: source color and theme metadata
//! ```
//!
//! ## Features
//! - `XDG_DATA_HOME` support with a `~/.local/share` fallback
//! - `XDG_CONFIG_HOME` support with a `~/.config` fallback, used by the Qt
//!   integration
//! - Path derivation that cannot escape the theme directory because it takes a
//!   validated [`ThemeId`]
//! - Directory creation in a single [`ThemePaths::ensure`] call
//!
//! ## Related
//! - [`crate::constants`][]: file and directory names
//! - [`crate::domain::theme::ThemeId`][]: validated theme identifier
//! - [`crate::theme_store::ThemeStore`][]: consumer of these paths
//! - [`crate::backend::qt`][]: consumes the XDG helpers for Qt output
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{
    env,
    path::{Path, PathBuf},
};

use rde_core::errors::{RdeError, RdeResult};

use crate::{
    constants::{DATA_HOME_SUBDIR, MANIFEST_FILE_NAME, REGISTRY_FILE_NAME, THEMES_DIR_NAME},
    domain::theme::ThemeId,
};

/// Filesystem layout of the theme database.
///
/// The root is the single source of truth; every other path is derived from it
/// so tests can point the service at a temporary directory.
///
/// # Example
/// ```text
/// ThemePaths::resolve()?.root() == ~/.local/share/rde/rde-theme
/// ```
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ThemePaths {
    /// Root directory of the theme database.
    root: PathBuf,
}

impl ThemePaths {
    /// Resolves the theme database location following the XDG base directory
    /// specification.
    ///
    /// # Workflow
    /// 1. Use `$XDG_DATA_HOME` when it is set to a non-empty value
    /// 2. Otherwise fall back to `$HOME/.local/share`
    /// 3. Append [`DATA_HOME_SUBDIR`] (`rde/rde-theme`)
    ///
    /// # Errors
    /// Returns [`RdeError::NotFound`] when neither `XDG_DATA_HOME` nor `HOME`
    /// is available, since the database location cannot be determined.
    pub fn resolve() -> RdeResult<Self> {
        Ok(Self::from_root(xdg_data_home()?.join(DATA_HOME_SUBDIR)))
    }

    /// Builds a layout rooted at an explicit directory.
    ///
    /// Used by tests and by callers that need an isolated theme database.
    pub fn from_root(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Returns the root directory of the theme database.
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Returns the path of the theme registry file (`themes.toml`).
    pub fn registry_file(&self) -> PathBuf {
        self.root.join(REGISTRY_FILE_NAME)
    }

    /// Returns the directory containing one subdirectory per installed theme.
    pub fn themes_dir(&self) -> PathBuf {
        self.root.join(THEMES_DIR_NAME)
    }

    /// Returns the directory of a single installed theme.
    pub fn theme_dir(&self, theme: &ThemeId) -> PathBuf {
        self.themes_dir().join(theme.as_str())
    }

    /// Returns the manifest path of a single installed theme.
    pub fn manifest_file(&self, theme: &ThemeId) -> PathBuf {
        self.theme_dir(theme).join(MANIFEST_FILE_NAME)
    }

    /// Creates the root and `themes/` directories when they are missing.
    ///
    /// # Errors
    /// Returns [`RdeError::Io`] when the directories cannot be created, for
    /// example because the data home is not writable.
    pub fn ensure(&self) -> RdeResult<()> {
        std::fs::create_dir_all(self.themes_dir()).map_err(RdeError::Io)
    }
}

/// Returns the XDG data home, where user data such as the theme database and
/// KDE color scheme files live.
///
/// # Returns
/// `$XDG_DATA_HOME` when it is set to a non-empty value, otherwise
/// `$HOME/.local/share`.
///
/// # Errors
/// Returns [`RdeError::NotFound`] when neither variable provides a directory.
pub fn xdg_data_home() -> RdeResult<PathBuf> {
    match environment_dir("XDG_DATA_HOME") {
        Some(directory) => Ok(directory),
        None => Ok(home_dir()?.join(".local").join("share")),
    }
}

/// Returns the XDG configuration home used by the Qt and KDE configuration
/// files.
///
/// # Returns
/// `$XDG_CONFIG_HOME` when it is set to a non-empty value, otherwise
/// `$HOME/.config`.
///
/// # Errors
/// Returns [`RdeError::NotFound`] when neither variable provides a directory.
pub fn xdg_config_home() -> RdeResult<PathBuf> {
    match environment_dir("XDG_CONFIG_HOME") {
        Some(directory) => Ok(directory),
        None => Ok(home_dir()?.join(".config")),
    }
}

/// Reads an environment variable as a non-empty directory path.
fn environment_dir(variable: &str) -> Option<PathBuf> {
    env::var_os(variable)
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
}

/// Returns the user's home directory from the environment.
///
/// # Errors
/// Returns [`RdeError::NotFound`] when `HOME` is unset or empty.
fn home_dir() -> RdeResult<PathBuf> {
    env::var_os("HOME")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| RdeError::NotFound("home directory is not available".to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derives_every_path_from_the_root() {
        let theme = ThemeId::new("ocean").expect("valid theme id");
        let paths = ThemePaths::from_root("/tmp/rde-theme-test");

        assert_eq!(paths.root(), Path::new("/tmp/rde-theme-test"));
        assert_eq!(
            paths.registry_file(),
            Path::new("/tmp/rde-theme-test/themes.toml")
        );
        assert_eq!(paths.themes_dir(), Path::new("/tmp/rde-theme-test/themes"));
        assert_eq!(
            paths.manifest_file(&theme),
            Path::new("/tmp/rde-theme-test/themes/ocean/theme.toml")
        );
    }
}
