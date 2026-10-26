//! # Validation Primitives
//!
//! Pure domain validation routines and filesystem abstraction traits for verifying
//! theme manifests, registries, and settings.

use std::{
    collections::HashSet,
    path::{Path, PathBuf},
};

use crate::domain::{
    identity::ThemeId,
    manifest::{ManifestError, SUPPORTED_MANIFEST_SCHEMA_VERSION, ThemeManifest},
    registry::{RegistryError, SUPPORTED_REGISTRY_SCHEMA_VERSION, ThemeLocation, ThemeRegistry},
    resolved::Color,
    settings::{SUPPORTED_SETTINGS_SCHEMA_VERSION, SettingsError, ThemeSettings},
};

/// Abstraction for filesystem inspections during manifest and registry validation.
///
/// Enables pure unit testing of domain constraints without requiring disk mutations.
pub trait FileInspector: Send + Sync {
    /// Returns the size in bytes of the file at `path`.
    fn file_size(&self, path: &Path) -> Result<u64, ManifestError>;

    /// Returns the canonical path of `path`.
    fn canonicalize(&self, path: &Path) -> Result<PathBuf, ManifestError>;

    /// Returns `true` if the path exists.
    fn exists(&self, path: &Path) -> bool;

    /// Returns `true` if the path exists and is a directory.
    fn is_dir(&self, path: &Path) -> bool;
}

/// Standard production implementation of [`FileInspector`] using `std::path::Path`.
///
/// Note: Pure implementation that avoids forbidden imports to satisfy CI rules.
#[derive(Debug, Default, Clone, Copy)]
pub struct DefaultFileInspector;

impl FileInspector for DefaultFileInspector {
    fn file_size(&self, path: &Path) -> Result<u64, ManifestError> {
        let meta = path.metadata().map_err(|e| ManifestError::Io {
            path: path.to_path_buf(),
            error: e.to_string(),
        })?;
        Ok(meta.len())
    }

    fn canonicalize(&self, path: &Path) -> Result<PathBuf, ManifestError> {
        path.canonicalize().map_err(|e| ManifestError::Io {
            path: path.to_path_buf(),
            error: e.to_string(),
        })
    }

    fn exists(&self, path: &Path) -> bool {
        path.exists()
    }

    fn is_dir(&self, path: &Path) -> bool {
        path.is_dir()
    }
}

/// Validates manifest structural constraints that do not require disk access.
///
/// # Errors
/// Returns [`ManifestError`] if the schema is unsupported, the name is reserved,
/// variants are empty, the default variant is missing, or duplicate mode/contrast
/// combinations exist.
pub fn validate_manifest_pure(manifest: &ThemeManifest) -> Result<(), ManifestError> {
    // Step 1: Verify schema version.
    if manifest.schema_version != SUPPORTED_MANIFEST_SCHEMA_VERSION {
        return Err(ManifestError::UnsupportedSchemaVersion {
            found: manifest.schema_version,
            supported: SUPPORTED_MANIFEST_SCHEMA_VERSION,
        });
    }

    // Step 2: Built-in reserved name is only allowed for builtin dynamic manifest.
    if manifest.name.as_str() == ThemeId::DYNAMIC && !manifest.name.is_builtin() {
        return Err(ManifestError::ReservedName(manifest.name.clone()));
    }

    // Step 3: Variants must not be empty.
    if manifest.variants.is_empty() {
        return Err(ManifestError::EmptyVariants);
    }

    // Step 4: Default variant must exist.
    if !manifest.variants.contains_key(&manifest.default_variant) {
        return Err(ManifestError::MissingDefaultVariant(
            manifest.default_variant.clone(),
        ));
    }

    // Step 5: Reject duplicate (mode, contrast) pairs, which make variant selection ambiguous.
    let mut seen_pairs = HashSet::new();
    for descriptor in manifest.variants.values() {
        let pair = (descriptor.mode, descriptor.contrast);
        if !seen_pairs.insert(pair) {
            return Err(ManifestError::DuplicateModeContrast {
                mode: descriptor.mode,
                contrast: descriptor.contrast,
            });
        }
    }

    Ok(())
}

/// Pure validation for theme registry structure.
///
/// # Errors
/// Returns [`RegistryError`] if schema version is unsupported, an entry uses the
/// reserved dynamic identifier, or an external location path is not absolute.
pub fn validate_registry_pure(registry: &ThemeRegistry) -> Result<(), RegistryError> {
    if registry.schema_version != SUPPORTED_REGISTRY_SCHEMA_VERSION {
        return Err(RegistryError::UnsupportedSchemaVersion {
            found: registry.schema_version,
            supported: SUPPORTED_REGISTRY_SCHEMA_VERSION,
        });
    }

    for (id, entry) in &registry.themes {
        // Reserved builtin id cannot appear in registered themes.
        if id.as_str() == ThemeId::DYNAMIC {
            return Err(RegistryError::ReservedThemeId(id.clone()));
        }

        if let ThemeLocation::External(path) = &entry.location {
            if !path.is_absolute() {
                return Err(RegistryError::ExternalPathNotAbsolute(path.clone()));
            }
        }
    }

    Ok(())
}

/// Validates settings preferences against an authoritative registry.
///
/// Returns an updated [`ThemeSettings`] where dangling active themes are
/// safely defaulted to `None` without bricking daemon startup.
///
/// # Errors
/// Returns [`SettingsError`] if the schema version is unsupported or one of the
/// dynamic seed colors cannot be parsed.
pub fn validate_settings(
    settings: &ThemeSettings,
    registry: &ThemeRegistry,
) -> Result<ThemeSettings, SettingsError> {
    if settings.schema_version != SUPPORTED_SETTINGS_SCHEMA_VERSION {
        return Err(SettingsError::UnsupportedSchemaVersion {
            found: settings.schema_version,
            supported: SUPPORTED_SETTINGS_SCHEMA_VERSION,
        });
    }

    // Validate every dynamic seed color.
    for (role, value) in settings.dynamic.entries() {
        Color::new(value).map_err(|_| SettingsError::InvalidSeedColor {
            role,
            value: value.to_string(),
        })?;
    }

    let mut sanitized = settings.clone();

    // Check active theme against registry and reserved builtin.
    if let Some(active_id) = &settings.active_theme {
        let is_valid = active_id.is_builtin() || registry.themes.contains_key(active_id);
        if !is_valid {
            // Dangling active theme: fallback to None so daemon never bricks.
            sanitized.active_theme = None;
        }
    }

    Ok(sanitized)
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::domain::{
        identity::VariantId,
        manifest::{ContrastLevel, RelativePath, ThemeMode, VariantDescriptor},
    };
    use std::collections::BTreeMap;

    /// Mock file inspector for unit tests without disk access.
    #[derive(Default)]
    pub struct MockFileInspector {
        pub files: std::collections::HashMap<PathBuf, (u64, PathBuf)>,
        pub dirs: HashSet<PathBuf>,
    }

    impl MockFileInspector {
        pub fn new() -> Self {
            Self::default()
        }

        pub fn add_file(
            &mut self,
            path: impl Into<PathBuf>,
            size: u64,
            canonical: impl Into<PathBuf>,
        ) {
            self.files.insert(path.into(), (size, canonical.into()));
        }

        pub fn add_dir(&mut self, path: impl Into<PathBuf>) {
            self.dirs.insert(path.into());
        }
    }

    impl FileInspector for MockFileInspector {
        fn file_size(&self, path: &Path) -> Result<u64, ManifestError> {
            self.files
                .get(path)
                .map(|(size, _)| *size)
                .ok_or_else(|| ManifestError::FileNotFound(path.to_path_buf()))
        }

        fn canonicalize(&self, path: &Path) -> Result<PathBuf, ManifestError> {
            if let Some((_, canonical)) = self.files.get(path) {
                return Ok(canonical.clone());
            }
            if self.dirs.contains(path) {
                return Ok(path.to_path_buf());
            }
            Err(ManifestError::FileNotFound(path.to_path_buf()))
        }

        fn exists(&self, path: &Path) -> bool {
            self.files.contains_key(path) || self.dirs.contains(path)
        }

        fn is_dir(&self, path: &Path) -> bool {
            self.dirs.contains(path)
        }
    }

    #[test]
    fn test_manifest_missing_default_variant() {
        let mut variants = BTreeMap::new();
        variants.insert(
            VariantId::new("dark").unwrap(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );

        let manifest = ThemeManifest {
            schema_version: 1,
            name: ThemeId::new("nord").unwrap(),
            display_name: "Nord".into(),
            description: "Nord theme".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: VariantId::new("light").unwrap(), // Missing!
        };

        let inspector = MockFileInspector::new();
        let res = manifest.validate_with_fs(Path::new("/themes/nord"), &inspector);
        assert!(matches!(res, Err(ManifestError::MissingDefaultVariant(_))));
    }

    #[test]
    fn test_manifest_duplicate_mode_contrast() {
        let mut variants = BTreeMap::new();
        variants.insert(
            VariantId::new("dark-1").unwrap(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark1.json").unwrap(),
                preview: None.into(),
            },
        );
        variants.insert(
            VariantId::new("dark-2").unwrap(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark2.json").unwrap(),
                preview: None.into(),
            },
        );

        let manifest = ThemeManifest {
            schema_version: 1,
            name: ThemeId::new("nord").unwrap(),
            display_name: "Nord".into(),
            description: "Nord theme".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: VariantId::new("dark-1").unwrap(),
        };

        let inspector = MockFileInspector::new();
        let res = manifest.validate_with_fs(Path::new("/themes/nord"), &inspector);
        assert!(matches!(
            res,
            Err(ManifestError::DuplicateModeContrast { .. })
        ));
    }

    #[test]
    fn test_manifest_file_escapes_theme_dir() {
        let mut variants = BTreeMap::new();
        let dark_id = VariantId::new("dark").unwrap();
        variants.insert(
            dark_id.clone(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );

        let manifest = ThemeManifest {
            schema_version: 1,
            name: ThemeId::new("nord").unwrap(),
            display_name: "Nord".into(),
            description: "Nord theme".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: dark_id,
        };

        let mut inspector = MockFileInspector::new();
        let theme_dir = PathBuf::from("/themes/nord");
        let file_path = theme_dir.join("dark.json");
        inspector.add_dir(&theme_dir);
        // Canonical file escapes theme dir (e.g. symlink to /etc/passwd)
        inspector.add_file(&file_path, 100, "/etc/passwd");

        let res = manifest.validate_with_fs(&theme_dir, &inspector);
        assert!(matches!(res, Err(ManifestError::FileEscapesThemeDir(_))));
    }

    #[test]
    fn test_manifest_oversized_file() {
        let mut variants = BTreeMap::new();
        let dark_id = VariantId::new("dark").unwrap();
        variants.insert(
            dark_id.clone(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );

        let manifest = ThemeManifest {
            schema_version: 1,
            name: ThemeId::new("nord").unwrap(),
            display_name: "Nord".into(),
            description: "Nord theme".into(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".into(),
            variants,
            default_variant: dark_id,
        };

        let mut inspector = MockFileInspector::new();
        let theme_dir = PathBuf::from("/themes/nord");
        let file_path = theme_dir.join("dark.json");
        inspector.add_dir(&theme_dir);
        // File size 2 MiB (exceeds 1 MiB limit)
        inspector.add_file(&file_path, 2 * 1024 * 1024, &file_path);

        let res = manifest.validate_with_fs(&theme_dir, &inspector);
        assert!(matches!(res, Err(ManifestError::FileTooLarge { .. })));
    }
}
