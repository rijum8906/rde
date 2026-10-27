//! # Disk-Based Theme Repository
//!
//! Implements [`ThemeRepository`] backed by standard filesystem structures and XDG directories.

use async_trait::async_trait;
use std::{collections::BTreeMap, path::PathBuf};
use tracing::{debug, info, warn};

use crate::{
    backend::material::compute_color_roles,
    domain::{
        identity::{ThemeId, VariantId},
        manifest::{BUILTIN_DYNAMIC_VARIANT_DIR, ThemeManifest, VariantDescriptor},
        registry::{ThemeEntry, ThemeLocation, ThemeRegistry, ThemeSource},
        resolved::{
            Motion, ResolvedTheme, SUPPORTED_RESOLVED_SCHEMA_VERSION, Shape, Typography,
            VariantKind,
        },
        settings::ThemeSettings,
    },
    fs::write_atomic,
    theme_store::{ThemeError, ThemeRepository},
};

/// Default system themes directory.
pub const DEFAULT_SYSTEM_THEMES_DIR: &str = "/usr/share/rde/themes";

/// Filesystem implementation of [`ThemeRepository`].
#[derive(Debug, Clone)]
pub struct DiskThemeRepository {
    themes_dir: PathBuf,
    config_dir: PathBuf,
    cache_dir: PathBuf,
    system_themes_dir: PathBuf,
}

impl DiskThemeRepository {
    /// Creates a new [`DiskThemeRepository`] pointing at the given directories.
    ///
    /// # Parameters
    /// - `themes_dir`: user themes directory containing `themes.toml` and theme subdirs
    /// - `config_dir`: user configuration directory containing `settings.toml`
    /// - `cache_dir`: cache directory where `current.json` and generated assets reside
    #[must_use]
    pub fn new(themes_dir: PathBuf, config_dir: PathBuf, cache_dir: PathBuf) -> Self {
        Self {
            themes_dir,
            config_dir,
            cache_dir,
            system_themes_dir: PathBuf::from(DEFAULT_SYSTEM_THEMES_DIR),
        }
    }

    /// Configures a custom system themes search directory.
    #[must_use]
    pub fn with_system_themes(mut self, system_themes_dir: PathBuf) -> Self {
        self.system_themes_dir = system_themes_dir;
        self
    }

    /// Path to the factual `themes.toml` registry file.
    #[must_use]
    pub fn registry_path(&self) -> PathBuf {
        self.themes_dir.join("themes.toml")
    }

    /// Path to the user preference `settings.toml` file.
    #[must_use]
    pub fn settings_path(&self) -> PathBuf {
        self.config_dir.join("settings.toml")
    }

    /// Path to the cached `current.json` resolved theme payload.
    #[must_use]
    pub fn current_cache_path(&self) -> PathBuf {
        self.cache_dir.join("current.json")
    }

    /// Atomically writes the resolved theme cache payload (`current.json`).
    ///
    /// # Errors
    /// Returns [`ThemeError::Io`] if atomic write fails.
    pub fn save_current_cache(&self, resolved: &ResolvedTheme) -> Result<(), ThemeError> {
        let path = self.current_cache_path();
        let json = serde_json::to_vec_pretty(resolved)
            .map_err(|e| ThemeError::Serialization(e.to_string()))?;
        write_atomic(&path, &json)?;
        Ok(())
    }

    /// Resolves the absolute directory path of a theme.
    fn resolve_theme_dir(&self, id: &ThemeId, entry: &ThemeEntry) -> PathBuf {
        match &entry.location {
            ThemeLocation::User => self.themes_dir.join(id.as_str()),
            ThemeLocation::System => self.system_themes_dir.join(id.as_str()),
            ThemeLocation::External(path) => path.clone(),
        }
    }

    /// Absolute path of the generated payload file backing a built-in variant.
    ///
    /// # Parameters
    /// - `descriptor`: variant descriptor carrying the relative payload path
    ///
    /// # Returns
    /// The payload path below the built-in theme root (the cache directory).
    fn dynamic_variant_path(&self, descriptor: &VariantDescriptor) -> PathBuf {
        self.cache_dir.join(descriptor.file_path.as_path())
    }

    /// Generates and materializes every variant payload of the built-in dynamic theme.
    ///
    /// The four seeds persisted in the dynamic settings drive every mode/contrast
    /// variant, so the generated set always stays internally consistent. Payloads
    /// are written atomically, which keeps concurrent readers from observing a
    /// partially written variant file.
    ///
    /// # Parameters
    /// - `manifest`: built-in dynamic manifest whose variants are rendered
    ///
    /// # Errors
    /// Returns [`ThemeError::Io`] when a payload cannot be written and
    /// [`ThemeError::Serialization`] when a payload cannot be encoded.
    async fn materialize_dynamic_variants(
        &self,
        manifest: &ThemeManifest,
    ) -> Result<(), ThemeError> {
        // Step 1: Load the dynamic inputs, recovering to defaults on failure.
        let settings = match self.load_settings().await {
            Ok(settings) => settings,
            Err(err) => {
                warn!(error = %err, "Failed to load settings for the dynamic theme; using defaults");
                ThemeSettings::default()
            }
        };

        // Step 2: Read the four seeds shared by all variants.
        let seeds = settings.dynamic.color_seeds();

        // Step 3: Render and atomically persist every variant payload.
        for (variant_id, descriptor) in &manifest.variants {
            let payload = ResolvedTheme {
                schema_version: SUPPORTED_RESOLVED_SCHEMA_VERSION,
                theme_id: ThemeId::builtin_dynamic(),
                variant: variant_id.clone(),
                kind: VariantKind::Dynamic,
                colors: compute_color_roles(&seeds, descriptor.mode, descriptor.contrast),
                typography: Typography::default(),
                shape: Shape::default(),
                motion: Motion::default(),
            };

            let bytes = serde_json::to_vec_pretty(&payload)
                .map_err(|err| ThemeError::Serialization(err.to_string()))?;
            let path = self.dynamic_variant_path(descriptor);

            // Skip payloads that are already up to date to avoid pointless rewrites
            // when only one mode or contrast actually changed.
            if std::fs::read(&path).ok().as_deref() == Some(bytes.as_slice()) {
                continue;
            }

            write_atomic(&path, &bytes).unwrap();
        }

        debug!(
            variants = manifest.variants.len(),
            primary = seeds.primary.as_str(),
            secondary = seeds.secondary.as_str(),
            tertiary = seeds.tertiary.as_str(),
            error = seeds.error.as_str(),
            dir = %self.cache_dir.join(BUILTIN_DYNAMIC_VARIANT_DIR).display(),
            "Materialized built-in dynamic theme variants"
        );

        Ok(())
    }
}

#[async_trait]
impl ThemeRepository for DiskThemeRepository {
    async fn manifest(&self, id: &ThemeId) -> Result<ThemeManifest, ThemeError> {
        // Step 1: The built-in dynamic manifest is constructed in memory and never
        // validated against disk: its variant payloads are generated on resolution.
        if id.is_builtin() {
            return Ok(ThemeManifest::builtin_dynamic());
        }

        // Step 2: Look up theme in the registry.
        let registry = self.load_registry().await?;
        let entry = registry
            .themes
            .get(id)
            .ok_or_else(|| ThemeError::NotFound(id.clone()))?;

        // Step 3: Read theme.toml from theme directory.
        let theme_dir = self.resolve_theme_dir(id, entry);
        let manifest_path = theme_dir.join("theme.toml");

        let content = std::fs::read_to_string(&manifest_path)?;

        let manifest: ThemeManifest =
            toml::from_str(&content).map_err(|e| ThemeError::Serialization(e.to_string()))?;

        // Step 4: Validate manifest.
        manifest.validate(&theme_dir)?;

        Ok(manifest)
    }

    async fn entry(&self, id: &ThemeId) -> Result<Option<ThemeEntry>, ThemeError> {
        if id.is_builtin() {
            return Ok(None);
        }
        let registry = self.load_registry().await?;
        Ok(registry.themes.get(id).cloned())
    }

    async fn list(&self) -> Result<Vec<ThemeId>, ThemeError> {
        let registry = self.load_registry().await?;
        Ok(registry.themes.keys().cloned().collect())
    }

    async fn load_registry(&self) -> Result<ThemeRegistry, ThemeError> {
        let path = self.registry_path();

        // Recovery Policy:
        // 1. If themes.toml is missing: rebuild and save.
        if !path.exists() {
            info!(path = %path.display(), "themes.toml missing; rebuilding registry from disk");
            return self.rebuild_registry().await;
        }

        // 2. Read and parse themes.toml.
        let content = match std::fs::read_to_string(&path) {
            Ok(c) => c,
            Err(source) => {
                warn!(path = %path.display(), error = %source, "Cannot read themes.toml; rebuilding");
                return self.rebuild_registry().await;
            }
        };

        let mut registry: ThemeRegistry = match toml::from_str(&content) {
            Ok(reg) => reg,
            Err(err) => {
                warn!(path = %path.display(), error = %err, "Corrupt themes.toml; rebuilding registry from disk");
                return self.rebuild_registry().await;
            }
        };

        // 3. Validate registry; rebuild if validation fails.
        if let Err(err) = registry.validate(&self.themes_dir, &self.system_themes_dir) {
            warn!(error = %err, "Registry validation failed; rebuilding from disk");
            return self.rebuild_registry().await;
        }

        Ok(registry)
    }

    async fn save_registry(&self, reg: &ThemeRegistry) -> Result<(), ThemeError> {
        let path = self.registry_path();
        let content =
            toml::to_string_pretty(reg).map_err(|e| ThemeError::Serialization(e.to_string()))?;
        write_atomic(&path, content.as_bytes())?;
        Ok(())
    }

    async fn load_settings(&self) -> Result<ThemeSettings, ThemeError> {
        let path = self.settings_path();

        // Step 1: A missing settings file simply means "use the defaults".
        if !path.exists() {
            warn!(path = %path.display(), "Settings file does not exist; using defaults");
            return Ok(ThemeSettings::default());
        }

        // Step 2: Read the file, propagating real I/O failures to the caller.
        let content = std::fs::read_to_string(&path)?;

        // Step 3: Recover from corrupt files instead of failing the service.
        match toml::from_str::<ThemeSettings>(&content) {
            Ok(settings) => Ok(settings),
            Err(err) => {
                warn!(path = %path.display(), error = %err, "Failed to parse settings.toml; recovering to defaults");
                Ok(ThemeSettings::default())
            }
        }
    }

    async fn save_settings(&self, settings: &ThemeSettings) -> Result<(), ThemeError> {
        let path = self.settings_path();
        let content = toml::to_string_pretty(settings)
            .map_err(|err| ThemeError::Serialization(err.to_string()))?;
        write_atomic(&path, content.as_bytes())?;
        Ok(())
    }

    async fn resolve_variant(
        &self,
        id: &ThemeId,
        variant: &VariantId,
    ) -> Result<ResolvedTheme, ThemeError> {
        // Step 1: Load the manifest together with the root its variant paths are relative to.
        let (manifest, theme_root) = if id.is_builtin() {
            (ThemeManifest::builtin_dynamic(), self.cache_dir.clone())
        } else {
            let registry = self.load_registry().await?;
            let entry = registry
                .themes
                .get(id)
                .ok_or_else(|| ThemeError::NotFound(id.clone()))?;
            let dir = self.resolve_theme_dir(id, entry);
            let manifest_path = dir.join("theme.toml");
            let content = std::fs::read_to_string(&manifest_path)?;
            let manifest: ThemeManifest =
                toml::from_str(&content).map_err(|e| ThemeError::Serialization(e.to_string()))?;
            manifest.validate(&dir)?;
            (manifest, dir)
        };

        // Step 2: Locate the requested variant descriptor.
        let descriptor =
            manifest
                .variants
                .get(variant)
                .ok_or_else(|| ThemeError::NoSuchVariant {
                    theme: id.clone(),
                    variant: variant.clone(),
                })?;

        // Step 3: Regenerate the built-in dynamic payloads so its descriptors point at
        // files that exist, mirroring how installed themes ship their payloads.
        if id.is_builtin() {
            self.materialize_dynamic_variants(&manifest).await?;
        }

        // Step 4: Read the payload through the single file-backed resolution path.
        let file_path = theme_root.join(descriptor.file_path.as_path());
        let content = std::fs::read_to_string(&file_path)?;

        let resolved: ResolvedTheme = serde_json::from_str(&content).map_err(|err| {
            ThemeError::Resolved(format!("failed to parse '{}': {err}", file_path.display()))
        })?;

        if resolved.schema_version != SUPPORTED_RESOLVED_SCHEMA_VERSION {
            return Err(ThemeError::SchemaUnsupported {
                found: resolved.schema_version,
                supported: SUPPORTED_RESOLVED_SCHEMA_VERSION,
            });
        }

        Ok(resolved)
    }

    async fn rebuild_registry(&self) -> Result<ThemeRegistry, ThemeError> {
        let mut themes = BTreeMap::new();

        // Scan user themes directory
        if self.themes_dir.is_dir() {
            if let Ok(entries) = std::fs::read_dir(&self.themes_dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() {
                        let manifest_file = path.join("theme.toml");
                        if manifest_file.is_file() {
                            if let Ok(content) = std::fs::read_to_string(&manifest_file) {
                                if let Ok(manifest) = toml::from_str::<ThemeManifest>(&content) {
                                    if manifest.validate(&path).is_ok() {
                                        themes.insert(
                                            manifest.name.clone(),
                                            ThemeEntry {
                                                location: ThemeLocation::User,
                                                source: ThemeSource::User,
                                                installed_at: 0,
                                            },
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Scan system themes directory
        if self.system_themes_dir.is_dir() {
            if let Ok(entries) = std::fs::read_dir(&self.system_themes_dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() {
                        let manifest_file = path.join("theme.toml");
                        if manifest_file.is_file() {
                            if let Ok(content) = std::fs::read_to_string(&manifest_file) {
                                if let Ok(manifest) = toml::from_str::<ThemeManifest>(&content) {
                                    if manifest.validate(&path).is_ok() {
                                        themes.entry(manifest.name.clone()).or_insert(ThemeEntry {
                                            location: ThemeLocation::System,
                                            source: ThemeSource::Package {
                                                name: "system".into(),
                                            },
                                            installed_at: 0,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        let registry = ThemeRegistry {
            schema_version: crate::domain::registry::SUPPORTED_REGISTRY_SCHEMA_VERSION,
            themes,
        };

        // Persist newly rebuilt registry
        self.save_registry(&registry).await?;

        Ok(registry)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        ContrastLevel, ThemeMode,
        resolved::{Color, ColorSeeds, Motion, Shape, Typography, VariantKind},
    };

    #[tokio::test]
    async fn test_disk_repository_resolve_static_variant() {
        let temp = tempfile::tempdir().unwrap();
        let user_themes = temp.path().join("data").join("themes");
        let config_dir = temp.path().join("config").join("themes");
        let cache_dir = temp.path().join("cache").join("theme");

        let repo = DiskThemeRepository::new(user_themes.clone(), config_dir, cache_dir);

        // Write a theme: "ocean"
        let ocean_dir = user_themes.join("ocean");
        std::fs::create_dir_all(&ocean_dir).unwrap();

        let dark_json_path = ocean_dir.join("dark.json");
        let dark_roles = compute_color_roles(
            &ColorSeeds::uniform(&Color::new("#006a6a").unwrap()),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        );
        let resolved = ResolvedTheme {
            schema_version: 1,
            theme_id: ThemeId::new("ocean").unwrap(),
            variant: VariantId::new("dark").unwrap(),
            kind: VariantKind::Static,
            colors: dark_roles,
            typography: Typography::default(),
            shape: Shape::default(),
            motion: Motion::default(),
        };

        std::fs::write(
            &dark_json_path,
            serde_json::to_string_pretty(&resolved).unwrap(),
        )
        .unwrap();

        let manifest_content = r#"
schema_version = 1
name = "ocean"
display_name = "Ocean"
description = "Ocean theme"
version = "1.0.0"
default_variant = "dark"

[variants.dark]
mode = "dark"
contrast = "normal"
file_path = "dark.json"
"#;
        std::fs::write(ocean_dir.join("theme.toml"), manifest_content).unwrap();

        // Rebuild registry so it discovers ocean
        let registry = repo.rebuild_registry().await.unwrap();
        assert!(
            registry
                .themes
                .contains_key(&ThemeId::new("ocean").unwrap())
        );

        // Resolve variant
        let resolved_out = repo
            .resolve_variant(
                &ThemeId::new("ocean").unwrap(),
                &VariantId::new("dark").unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resolved_out.theme_id.as_str(), "ocean");
        assert_eq!(resolved_out.variant.as_str(), "dark");
        assert_eq!(resolved_out.colors.primary, resolved.colors.primary);
        assert_eq!(resolved_out.kind, VariantKind::Static);
    }

    #[tokio::test]
    async fn test_builtin_dynamic_resolves_and_materializes_variants() {
        let temp = tempfile::tempdir().unwrap();
        let user_themes = temp.path().join("data").join("themes");
        let config_dir = temp.path().join("config").join("themes");
        let cache_dir = temp.path().join("cache").join("theme");

        let repo = DiskThemeRepository::new(user_themes, config_dir.clone(), cache_dir.clone());

        // Pin the dynamic seeds so the expected palette is deterministic.
        let settings = ThemeSettings {
            dynamic: crate::domain::settings::DynamicSettings {
                primary: "#006a6a".to_string(),
                secondary: "#6750a4".to_string(),
                tertiary: "#b52700".to_string(),
                error: "#b90063".to_string(),
            },
            ..ThemeSettings::default()
        };
        repo.save_settings(&settings).await.unwrap();

        let builtin = ThemeId::builtin_dynamic();
        let resolved = repo
            .resolve_variant(
                &builtin,
                &VariantId::new(VariantId::DARK_HIGH_CONTRAST).unwrap(),
            )
            .await
            .unwrap();

        // Step 1: The published payload is the requested dynamic variant.
        assert_eq!(resolved.theme_id, builtin);
        assert_eq!(resolved.variant.as_str(), VariantId::DARK_HIGH_CONTRAST);
        assert_eq!(resolved.kind, VariantKind::Dynamic);

        // Step 2: Colors match the Material 3 derivation from the configured seeds.
        let expected = compute_color_roles(
            &ColorSeeds {
                primary: Color::new("#006a6a").unwrap(),
                secondary: Color::new("#6750a4").unwrap(),
                tertiary: Color::new("#b52700").unwrap(),
                error: Color::new("#b90063").unwrap(),
            },
            ThemeMode::Dark,
            ContrastLevel::High,
        );
        assert_eq!(resolved.colors, expected);

        // Step 3: Every variant descriptor now points at a materialized payload file.
        for variant in [
            VariantId::LIGHT,
            VariantId::LIGHT_MEDIUM_CONTRAST,
            VariantId::LIGHT_HIGH_CONTRAST,
            VariantId::DARK,
            VariantId::DARK_MEDIUM_CONTRAST,
            VariantId::DARK_HIGH_CONTRAST,
        ] {
            let path = cache_dir
                .join(BUILTIN_DYNAMIC_VARIANT_DIR)
                .join(format!("{variant}.json"));
            assert!(path.is_file(), "missing generated payload at {path:?}");
        }

        // Step 4: The generated set is readable through the static resolution path.
        let manifest = repo.manifest(&builtin).await.unwrap();
        manifest.validate(&cache_dir).unwrap();
    }

    #[tokio::test]
    async fn test_builtin_dynamic_falls_back_without_usable_seed() {
        let temp = tempfile::tempdir().unwrap();
        let repo = DiskThemeRepository::new(
            temp.path().join("data"),
            temp.path().join("config"),
            temp.path().join("cache"),
        );

        // No settings at all: the default seeds drive the palette.
        let resolved = repo
            .resolve_variant(
                &ThemeId::builtin_dynamic(),
                &VariantId::new("dark").unwrap(),
            )
            .await
            .unwrap();

        let expected = compute_color_roles(
            &ColorSeeds::fallback(),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        );
        assert_eq!(resolved.colors, expected);
        assert_eq!(resolved.kind, VariantKind::Dynamic);
    }

    #[tokio::test]
    async fn test_manifest_with_dot_dot_rejected() {
        let manifest_content = r#"
schema_version = 1
name = "hacker"
display_name = "Hacker"
description = "Malicious theme"
version = "1.0.0"
default_variant = "dark"

[variants.dark]
mode = "dark"
contrast = "normal"
file_path = "../outside.json"
"#;
        let res = toml::from_str::<ThemeManifest>(manifest_content);
        assert!(
            res.is_err(),
            "Manifest with '..' in relative path must fail deserialization"
        );
    }
}
