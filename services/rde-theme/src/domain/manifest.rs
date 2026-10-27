//! # Author-Owned Theme Manifest
//!
//! Models `theme.toml` files packaged inside theme directories.
//!
//! Manifests are author-owned, read-only to the daemon, and define variants,
//! color modes, contrast levels, and asset references.

use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    fmt,
    ops::Deref,
    path::{Component, Path, PathBuf},
};
use thiserror::Error;
use zbus::zvariant::{Optional, Type};

use crate::domain::identity::{ThemeId, VariantId};
use crate::domain::validation::{DefaultFileInspector, FileInspector};

/// Maximum allowed file size for a variant JSON file (1 MiB).
pub const MAX_VARIANT_FILE_SIZE_BYTES: u64 = 1024 * 1024;

/// Supported schema version for theme manifests.
pub const SUPPORTED_MANIFEST_SCHEMA_VERSION: u32 = 1;

/// Directory holding the generated variant payloads of the built-in dynamic theme.
///
/// The directory is relative to the theme root the daemon resolves variant paths
/// against (the cache directory for the built-in theme).
pub const BUILTIN_DYNAMIC_VARIANT_DIR: &str = "rde-dynamic";

/// Variant definitions of the built-in dynamic theme: `(id, label, mode, contrast)`.
const BUILTIN_DYNAMIC_VARIANTS: &[(&str, &str, ThemeMode, ContrastLevel)] = &[
    (
        VariantId::LIGHT,
        "Light",
        ThemeMode::Light,
        ContrastLevel::Normal,
    ),
    (
        VariantId::LIGHT_MEDIUM_CONTRAST,
        "Light (medium contrast)",
        ThemeMode::Light,
        ContrastLevel::Medium,
    ),
    (
        VariantId::LIGHT_HIGH_CONTRAST,
        "Light (high contrast)",
        ThemeMode::Light,
        ContrastLevel::High,
    ),
    (
        VariantId::DARK,
        "Dark",
        ThemeMode::Dark,
        ContrastLevel::Normal,
    ),
    (
        VariantId::DARK_MEDIUM_CONTRAST,
        "Dark (medium contrast)",
        ThemeMode::Dark,
        ContrastLevel::Medium,
    ),
    (
        VariantId::DARK_HIGH_CONTRAST,
        "Dark (high contrast)",
        ThemeMode::Dark,
        ContrastLevel::High,
    ),
];

/// Errors that can occur during theme manifest validation or parsing.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum ManifestError {
    /// Schema version is not supported by this daemon.
    #[error("unsupported manifest schema version {found}, expected {supported}")]
    UnsupportedSchemaVersion { found: u32, supported: u32 },

    /// Manifest name is the reserved dynamic id in a non-builtin theme.
    #[error("theme manifest uses reserved name '{0}'")]
    ReservedName(ThemeId),

    /// Manifest contains no variants.
    #[error("manifest variants map cannot be empty")]
    EmptyVariants,

    /// Default variant does not exist in the variants map.
    #[error("default variant '{0}' does not exist in variants map")]
    MissingDefaultVariant(VariantId),

    /// Two variants declare the same mode and contrast combination.
    #[error("duplicate variant mode {mode:?} and contrast {contrast:?}")]
    DuplicateModeContrast {
        mode: ThemeMode,
        contrast: ContrastLevel,
    },

    /// Variant file was not found on disk.
    #[error("variant file not found at '{0}'")]
    FileNotFound(PathBuf),

    /// Variant file resolves outside of the theme directory.
    #[error("variant file at '{0}' escapes theme directory")]
    FileEscapesThemeDir(PathBuf),

    /// Variant file exceeds maximum allowed size.
    #[error("variant file at '{path}' is too large ({size} bytes, max {max} bytes)")]
    FileTooLarge { path: PathBuf, size: u64, max: u64 },

    /// Relative path contains invalid syntax or components.
    #[error("invalid relative path '{0}'")]
    InvalidRelativePath(String),

    /// Generic I/O or filesystem error during inspection.
    #[error("filesystem error inspecting '{path}': {error}")]
    Io { path: PathBuf, error: String },
}

/// A validated relative path inside a theme directory.
///
/// Rejects absolute paths, any path component equal to `..`, leading `~`,
/// and NUL bytes. Canonicalization escape checks are performed during manifest
/// validation when the enclosing directory is known.
#[derive(
    Debug, Default, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, Type,
)]
#[serde(try_from = "String", into = "String")]
pub struct RelativePath(String);

impl RelativePath {
    /// Validates and constructs a new [`RelativePath`].
    ///
    /// # Errors
    /// Returns [`ManifestError::InvalidRelativePath`] if path is absolute,
    /// contains `..`, begins with `~`, or contains a NUL byte.
    pub fn new(s: impl AsRef<str>) -> Result<Self, ManifestError> {
        let text = s.as_ref();

        // Step 1: Reject empty path or path containing NUL byte.
        if text.is_empty() || text.contains('\0') {
            return Err(ManifestError::InvalidRelativePath(text.to_string()));
        }

        // Step 2: Reject leading tilde.
        if text.starts_with('~') {
            return Err(ManifestError::InvalidRelativePath(text.to_string()));
        }

        let path = Path::new(text);

        // Step 3: Reject absolute paths.
        if path.is_absolute() {
            return Err(ManifestError::InvalidRelativePath(text.to_string()));
        }

        // Step 4: Reject any path component equal to `..` or root.
        for component in path.components() {
            match component {
                Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                    return Err(ManifestError::InvalidRelativePath(text.to_string()));
                }
                Component::CurDir | Component::Normal(_) => {}
            }
        }

        Ok(Self(text.to_string()))
    }

    /// Returns a string slice representing the relative path.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Returns the path as a standard [`Path`].
    #[must_use]
    pub fn as_path(&self) -> &Path {
        Path::new(&self.0)
    }
}

impl Deref for RelativePath {
    type Target = str;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl AsRef<Path> for RelativePath {
    fn as_ref(&self) -> &Path {
        self.as_path()
    }
}

impl fmt::Display for RelativePath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl TryFrom<String> for RelativePath {
    type Error = ManifestError;
    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::new(value)
    }
}

impl From<RelativePath> for String {
    fn from(path: RelativePath) -> Self {
        path.0
    }
}

/// The author-owned manifest format serialized as `theme.toml`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Type)]
pub struct ThemeManifest {
    /// Schema version for the manifest format.
    pub schema_version: u32,

    /// Unique identifier of the theme.
    pub name: ThemeId,

    /// User-facing display name.
    pub display_name: String,

    /// Short description of the theme.
    pub description: String,

    /// Optional author name or contact.
    #[serde(default)]
    pub author: Optional<String>,

    /// Optional license name (e.g. "MIT", "GPL-3.0").
    #[serde(default)]
    pub license: Optional<String>,

    /// Semantic version of the theme package.
    pub version: String,

    /// Map of available variants keyed by [`VariantId`]. Non-empty.
    pub variants: BTreeMap<VariantId, VariantDescriptor>,

    /// Identifier of the default variant.
    pub default_variant: VariantId,
}

impl ThemeManifest {
    /// Constructs the built-in dynamic theme manifest in memory.
    ///
    /// The built-in theme shares the author-owned manifest format, but its variant
    /// payloads are generated at runtime. Each descriptor therefore points at the
    /// file the daemon materializes under
    /// `<theme root>/rde-dynamic/<variant>.json`, so variant resolution stays
    /// file-backed exactly like an installed theme.
    ///
    /// # Returns
    /// A manifest with one variant per `(mode, contrast)` combination, defaulting
    /// to dark at normal contrast.
    #[must_use]
    pub fn builtin_dynamic() -> Self {
        let mut variants = BTreeMap::new();

        for (id, label, mode, contrast) in BUILTIN_DYNAMIC_VARIANTS {
            // Step 1: Derive the generated payload path. Both segments are literal
            // constants without traversal components, so the path is safe to build
            // directly through the validating constructor's invariant.
            let file_path = RelativePath(format!("{BUILTIN_DYNAMIC_VARIANT_DIR}/{id}.json"));

            // Step 2: Register the variant under its conventional identifier.
            variants.insert(
                VariantId::from_trusted_literal(id),
                VariantDescriptor {
                    mode: *mode,
                    contrast: *contrast,
                    display_name: Some((*label).to_string()).into(),
                    file_path,
                    preview: None.into(),
                },
            );
        }

        Self {
            schema_version: SUPPORTED_MANIFEST_SCHEMA_VERSION,
            name: ThemeId::builtin_dynamic(),
            display_name: "Dynamic".to_string(),
            description: "Generated from primary, secondary, tertiary, and error seed colors"
                .to_string(),
            author: Some("RDE Team".to_string()).into(),
            license: Some("MIT".to_string()).into(),
            version: "1.0.0".to_string(),
            variants,
            default_variant: VariantId::from_trusted_literal(VariantId::DARK),
        }
    }

    /// Selects the best matching variant identifier and descriptor for the requested mode and contrast.
    ///
    /// The resolution order is:
    /// 1. Exact match for `(mode, contrast)`.
    /// 2. Same mode at `Normal` contrast.
    /// 3. Same mode at `High` contrast.
    /// 4. Same mode at `Medium` contrast.
    /// 5. Fallback to `default_variant`, then to the first declared variant.
    ///
    /// # Parameters
    /// - `want_mode`: requested light/dark appearance
    /// - `want_contrast`: requested contrast level
    ///
    /// # Returns
    /// The selected [`VariantId`] together with its [`VariantDescriptor`], so callers
    /// can resolve the payload without matching descriptors by value.
    #[must_use]
    pub fn select_variant(
        &self,
        want_mode: ThemeMode,
        want_contrast: ContrastLevel,
    ) -> (&VariantId, &VariantDescriptor) {
        // Step 1: Check for an exact match on (mode, contrast).
        if let Some(found) = self.variants.iter().find(|(_, descriptor)| {
            descriptor.mode == want_mode && descriptor.contrast == want_contrast
        }) {
            return found;
        }

        // Step 2: Fall back to the same mode, preferring Normal, then High, then Medium contrast.
        let contrast_fallbacks = [
            ContrastLevel::Normal,
            ContrastLevel::High,
            ContrastLevel::Medium,
        ];
        for contrast in contrast_fallbacks {
            if let Some(found) = self.variants.iter().find(|(_, descriptor)| {
                descriptor.mode == want_mode && descriptor.contrast == contrast
            }) {
                return found;
            }
        }

        // Step 3: Fall back to the default variant, then to the first declared variant.
        self.variants
            .get_key_value(&self.default_variant)
            .or_else(|| self.variants.iter().next())
            .unwrap_or_else(|| unreachable!("validated manifests declare at least one variant"))
    }

    /// Selects the best matching variant descriptor for the requested mode and contrast.
    ///
    /// # Parameters
    /// - `want_mode`: requested light/dark appearance
    /// - `want_contrast`: requested contrast level
    ///
    /// # Returns
    /// Reference to the selected [`VariantDescriptor`].
    #[must_use]
    pub fn select(&self, want_mode: ThemeMode, want_contrast: ContrastLevel) -> &VariantDescriptor {
        self.select_variant(want_mode, want_contrast).1
    }

    /// Validates the manifest against disk paths using the default filesystem inspector.
    ///
    /// # Parameters
    /// - `dir`: root directory containing the theme and its files
    ///
    /// # Errors
    /// Returns [`ManifestError`] if validation fails.
    pub fn validate(&self, dir: &Path) -> Result<(), ManifestError> {
        self.validate_with_fs(dir, &DefaultFileInspector)
    }

    /// Validates the manifest using a provided [`FileInspector`].
    ///
    /// # Parameters
    /// - `dir`: root directory of the theme
    /// - `inspector`: implementation providing filesystem checks
    ///
    /// # Errors
    /// Returns [`ManifestError`] if any structural rule or file rule is violated.
    pub fn validate_with_fs<F: FileInspector>(
        &self,
        dir: &Path,
        inspector: &F,
    ) -> Result<(), ManifestError> {
        // Step 1: Run pure structural validation first.
        crate::domain::validation::validate_manifest_pure(self)?;

        // Step 2: Validate filesystem rules for the variant payload files.
        for descriptor in self.variants.values() {
            let relative = descriptor.file_path.as_path();
            let absolute = dir.join(relative);

            // Check existence.
            if !inspector.exists(&absolute) {
                return Err(ManifestError::FileNotFound(absolute));
            }

            // Check canonicalization to prevent escaping the theme directory.
            let canonical_dir = inspector.canonicalize(dir)?;
            let canonical_file = inspector.canonicalize(&absolute)?;

            if !canonical_file.starts_with(&canonical_dir) {
                return Err(ManifestError::FileEscapesThemeDir(absolute));
            }

            // Check file size (max 1 MiB).
            let size = inspector.file_size(&absolute)?;
            if size > MAX_VARIANT_FILE_SIZE_BYTES {
                return Err(ManifestError::FileTooLarge {
                    path: absolute,
                    size,
                    max: MAX_VARIANT_FILE_SIZE_BYTES,
                });
            }
        }

        Ok(())
    }
}

/// Description of a specific theme variant.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Type)]
pub struct VariantDescriptor {
    /// Light or Dark appearance mode.
    pub mode: ThemeMode,

    /// Contrast requirement for this variant.
    pub contrast: ContrastLevel,

    /// Optional human-readable label for user pickers.
    #[serde(default)]
    pub display_name: Optional<String>,

    /// Origin of the resolved variant payload.
    pub file_path: RelativePath,

    /// Optional preview image relative to theme directory.
    #[serde(default)]
    pub preview: Optional<RelativePath>,
}

/// Visual light/dark appearance preference.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[serde(rename_all = "kebab-case")]
pub enum ThemeMode {
    /// Light appearance scheme.
    #[default]
    Light,
    /// Dark appearance scheme.
    Dark,
}

/// Contrast level requirement for a theme variant.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Type)]
#[serde(rename_all = "kebab-case")]
pub enum ContrastLevel {
    /// Standard contrast level.
    #[default]
    Normal,
    /// Medium contrast enhancement.
    Medium,
    /// High contrast accessibility enhancement.
    High,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_relative_path_validation() {
        assert!(RelativePath::new("variants/dark.json").is_ok());
        assert!(RelativePath::new("preview.png").is_ok());
        assert_eq!(
            RelativePath::new("/etc/passwd"),
            Err(ManifestError::InvalidRelativePath("/etc/passwd".into()))
        );
        assert_eq!(
            RelativePath::new("../secret.json"),
            Err(ManifestError::InvalidRelativePath("../secret.json".into()))
        );
        assert_eq!(
            RelativePath::new("foo/../bar.json"),
            Err(ManifestError::InvalidRelativePath("foo/../bar.json".into()))
        );
        assert_eq!(
            RelativePath::new("~/theme.json"),
            Err(ManifestError::InvalidRelativePath("~/theme.json".into()))
        );
        assert_eq!(
            RelativePath::new("foo\0bar"),
            Err(ManifestError::InvalidRelativePath("foo\0bar".into()))
        );
    }

    #[test]
    fn test_select_fallback_hierarchy() {
        let mut variants = BTreeMap::new();
        let dark_id = VariantId::new("dark").unwrap();
        let light_id = VariantId::new("light").unwrap();

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
        variants.insert(
            light_id.clone(),
            VariantDescriptor {
                mode: ThemeMode::Light,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("light.json").unwrap(),
                preview: None.into(),
            },
        );

        let manifest = ThemeManifest {
            schema_version: 1,
            name: ThemeId::new("test-theme").unwrap(),
            display_name: "Test Theme".to_string(),
            description: "A test theme".to_string(),
            author: None.into(),
            license: None.into(),
            version: "1.0.0".to_string(),
            variants,
            default_variant: dark_id.clone(),
        };

        // Exact match
        let selected = manifest.select(ThemeMode::Light, ContrastLevel::Normal);
        assert_eq!(selected.mode, ThemeMode::Light);

        // Requested Light with High contrast falls back to Light Normal
        let selected_high = manifest.select(ThemeMode::Light, ContrastLevel::High);
        assert_eq!(selected_high.mode, ThemeMode::Light);
        assert_eq!(selected_high.contrast, ContrastLevel::Normal);

        // Exact match, including the selected variant identifier
        let (id, _) = manifest.select_variant(ThemeMode::Light, ContrastLevel::Normal);
        assert_eq!(id, &light_id);

        // Fallback to default variant when mode is missing
        let mut single_variant = BTreeMap::new();
        single_variant.insert(
            dark_id.clone(),
            VariantDescriptor {
                mode: ThemeMode::Dark,
                contrast: ContrastLevel::Normal,
                display_name: None.into(),
                file_path: RelativePath::new("dark.json").unwrap(),
                preview: None.into(),
            },
        );
        let dark_only_manifest = ThemeManifest {
            variants: single_variant,
            ..manifest
        };

        let fallback = dark_only_manifest.select(ThemeMode::Light, ContrastLevel::Normal);
        assert_eq!(fallback.mode, ThemeMode::Dark);
    }

    #[test]
    fn test_builtin_dynamic_manifest() {
        let dynamic = ThemeManifest::builtin_dynamic();
        assert_eq!(dynamic.name, ThemeId::builtin_dynamic());
        assert_eq!(dynamic.variants.len(), 6);
        assert_eq!(dynamic.default_variant.as_str(), VariantId::DARK);
        assert!(crate::domain::validation::validate_manifest_pure(&dynamic).is_ok());

        // Every variant payload is a generated file inside the dynamic variant directory.
        for (id, descriptor) in &dynamic.variants {
            assert_eq!(
                descriptor.file_path.as_str(),
                format!("{BUILTIN_DYNAMIC_VARIANT_DIR}/{id}.json")
            );
        }

        // Each mode/contrast combination selects its dedicated variant.
        let (id, descriptor) = dynamic.select_variant(ThemeMode::Light, ContrastLevel::High);
        assert_eq!(id.as_str(), VariantId::LIGHT_HIGH_CONTRAST);
        assert_eq!(descriptor.contrast, ContrastLevel::High);
    }
}
