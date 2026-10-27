//! # Machine-Owned Theme Registry
//!
//! Models `themes.toml` containing factual records of installed and available themes.
//!
//! This registry is machine-owned, fully regenerable by rescanning the filesystem,
//! and strictly separates facts from user preferences.

use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
};
use thiserror::Error;
use tracing::warn;

use crate::domain::{
    identity::ThemeId,
    validation::{DefaultFileInspector, FileInspector},
};

/// Supported schema version for `themes.toml`.
pub const SUPPORTED_REGISTRY_SCHEMA_VERSION: u32 = 1;

/// Validation errors for the theme registry.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum RegistryError {
    /// Schema version is unsupported.
    #[error("unsupported registry schema version {found}, expected {supported}")]
    UnsupportedSchemaVersion { found: u32, supported: u32 },

    /// Entry uses the reserved built-in dynamic theme identifier.
    #[error("registry entry uses reserved theme identifier '{0}'")]
    ReservedThemeId(ThemeId),

    /// External theme path is not absolute.
    #[error("external theme path '{0}' is not absolute")]
    ExternalPathNotAbsolute(PathBuf),

    /// External theme path does not exist on disk.
    #[error("external theme path '{0}' does not exist")]
    ExternalPathNotFound(PathBuf),

    /// Manifest file `theme.toml` is missing in theme directory.
    #[error("theme directory at '{0}' is missing 'theme.toml'")]
    MissingManifest(PathBuf),

    /// Theme manifest in directory failed validation.
    #[error("invalid manifest in '{path}': {reason}")]
    InvalidManifest { path: PathBuf, reason: String },
}

/// The authoritative factual registry of installed themes (`themes.toml`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemeRegistry {
    /// Schema version for the registry format.
    pub schema_version: u32,

    /// Authoritative index of themes on disk, keyed by [`ThemeId`].
    #[serde(default)]
    pub themes: BTreeMap<ThemeId, ThemeEntry>,
}

impl Default for ThemeRegistry {
    fn default() -> Self {
        Self {
            schema_version: SUPPORTED_REGISTRY_SCHEMA_VERSION,
            themes: BTreeMap::new(),
        }
    }
}

impl ThemeRegistry {
    /// Constructs a new empty registry with the current supported schema version.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Resolves the directory path for a given entry.
    ///
    /// - `User`: `$XDG_DATA_HOME/rde/themes/<id>`
    /// - `System`: `/usr/share/rde/themes/<id>`
    /// - `External(path)`: explicit absolute path
    #[must_use]
    pub fn resolve_path(
        &self,
        id: &ThemeId,
        entry: &ThemeEntry,
        user_themes_dir: &Path,
        system_themes_dir: &Path,
    ) -> PathBuf {
        match &entry.location {
            ThemeLocation::User => user_themes_dir.join(id.as_str()),
            ThemeLocation::System => system_themes_dir.join(id.as_str()),
            ThemeLocation::External(path) => path.clone(),
        }
    }

    /// Validates the registry against the filesystem, dropping dangling or invalid
    /// entries from in-memory state with a warning.
    ///
    /// # Errors
    /// Returns [`RegistryError`] if schema version is unsupported, an entry uses
    /// the reserved dynamic ID, or an external location path is not absolute.
    pub fn validate(
        &mut self,
        user_themes_dir: &Path,
        system_themes_dir: &Path,
    ) -> Result<(), RegistryError> {
        self.validate_with_fs(user_themes_dir, system_themes_dir, &DefaultFileInspector)
    }

    /// Validates the registry using a custom [`FileInspector`].
    ///
    /// # Errors
    /// Returns [`RegistryError`] for structural or security invariant violations.
    pub fn validate_with_fs<F: FileInspector>(
        &mut self,
        user_themes_dir: &Path,
        system_themes_dir: &Path,
        inspector: &F,
    ) -> Result<(), RegistryError> {
        // Step 1: Verify schema version.
        if self.schema_version != SUPPORTED_REGISTRY_SCHEMA_VERSION {
            return Err(RegistryError::UnsupportedSchemaVersion {
                found: self.schema_version,
                supported: SUPPORTED_REGISTRY_SCHEMA_VERSION,
            });
        }

        let mut dangling = Vec::new();

        // Step 2: Validate each entry.
        for (id, entry) in &self.themes {
            // Reserved dynamic id cannot appear in registered themes.
            if id.as_str() == ThemeId::DYNAMIC {
                return Err(RegistryError::ReservedThemeId(id.clone()));
            }

            // Check location.
            match &entry.location {
                ThemeLocation::External(path) => {
                    if !path.is_absolute() {
                        return Err(RegistryError::ExternalPathNotAbsolute(path.clone()));
                    }
                    if !inspector.is_dir(path) {
                        warn!(theme = %id, path = %path.display(), "External theme directory does not exist; dropping from in-memory registry");
                        dangling.push(id.clone());
                        continue;
                    }
                    let manifest_file = path.join("theme.toml");
                    if !inspector.exists(&manifest_file) {
                        warn!(theme = %id, path = %manifest_file.display(), "External theme missing theme.toml; dropping from in-memory registry");
                        dangling.push(id.clone());
                        continue;
                    }
                }
                ThemeLocation::User => {
                    let dir = user_themes_dir.join(id.as_str());
                    let manifest_file = dir.join("theme.toml");
                    if !inspector.exists(&manifest_file) {
                        warn!(theme = %id, path = %dir.display(), "User theme directory missing theme.toml; dropping from in-memory registry");
                        dangling.push(id.clone());
                        continue;
                    }
                }
                ThemeLocation::System => {
                    let dir = system_themes_dir.join(id.as_str());
                    let manifest_file = dir.join("theme.toml");
                    if !inspector.exists(&manifest_file) {
                        warn!(theme = %id, path = %dir.display(), "System theme directory missing theme.toml; dropping from in-memory registry");
                        dangling.push(id.clone());
                        continue;
                    }
                }
            }
        }

        // Step 3: Remove dangling themes from the in-memory registry only.
        for id in dangling {
            self.themes.remove(&id);
        }

        Ok(())
    }
}

/// Metadata entry for a single installed theme in the registry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemeEntry {
    /// Storage location category for the theme.
    #[serde(default)]
    pub location: ThemeLocation,

    /// Packaging or installation origin.
    #[serde(default)]
    pub source: ThemeSource,

    /// Installation timestamp (Unix seconds). Informational only.
    #[serde(default)]
    pub installed_at: i64,
}

impl Default for ThemeEntry {
    fn default() -> Self {
        Self {
            location: ThemeLocation::User,
            source: ThemeSource::User,
            installed_at: 0,
        }
    }
}

/// Storage location type of a theme.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case", tag = "kind", content = "path")]
pub enum ThemeLocation {
    /// Default user directory (`$XDG_DATA_HOME/rde/themes/<id>`).
    #[default]
    User,

    /// System directory (`/usr/share/rde/themes/<id>`).
    System,

    /// External directory with explicit validated absolute path.
    External(PathBuf),
}

/// Origin or packaging source of a theme.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case", tag = "kind")]
pub enum ThemeSource {
    /// Shipped via a system package.
    Package { name: String },

    /// Manually installed or created by user.
    #[default]
    User,

    /// Cloned or linked from local directory.
    Local { path: PathBuf },

    /// Downloaded from remote URL.
    Url { url: String },
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::validation::tests::MockFileInspector;

    #[test]
    fn test_registry_rejects_reserved_id() {
        let mut registry = ThemeRegistry::new();
        registry
            .themes
            .insert(ThemeId::builtin_dynamic(), ThemeEntry::default());

        let inspector = MockFileInspector::new();
        let res = registry.validate_with_fs(
            Path::new("/user/themes"),
            Path::new("/usr/share/rde/themes"),
            &inspector,
        );
        assert!(matches!(res, Err(RegistryError::ReservedThemeId(_))));
    }

    #[test]
    fn test_registry_rejects_non_absolute_external() {
        let mut registry = ThemeRegistry::new();
        let id = ThemeId::new("dev-theme").unwrap();
        registry.themes.insert(
            id,
            ThemeEntry {
                location: ThemeLocation::External(PathBuf::from("relative/path")),
                source: ThemeSource::User,
                installed_at: 0,
            },
        );

        let inspector = MockFileInspector::new();
        let res = registry.validate_with_fs(
            Path::new("/user/themes"),
            Path::new("/usr/share/rde/themes"),
            &inspector,
        );
        assert!(matches!(
            res,
            Err(RegistryError::ExternalPathNotAbsolute(_))
        ));
    }

    #[test]
    fn test_registry_drops_dangling_entry_with_warning() {
        let mut registry = ThemeRegistry::new();
        let id = ThemeId::new("deleted-theme").unwrap();
        registry.themes.insert(id.clone(), ThemeEntry::default());

        let inspector = MockFileInspector::new(); // Empty mock, no files
        let res = registry.validate_with_fs(
            Path::new("/user/themes"),
            Path::new("/usr/share/rde/themes"),
            &inspector,
        );

        // Validation succeeds, but deleted-theme is pruned from in-memory themes
        assert!(res.is_ok());
        assert!(!registry.themes.contains_key(&id));
    }
}
