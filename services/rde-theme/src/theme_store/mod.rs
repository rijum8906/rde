//! # Theme Repository Layer
//!
//! Defines the abstract [`ThemeRepository`] trait and domain persistence error types.

pub mod disk;

use async_trait::async_trait;
use thiserror::Error;

use crate::{
    backend::BackendError,
    domain::{
        IdError,
        error::{ManifestError, RegistryError, SettingsError},
        identity::{ThemeId, VariantId},
        manifest::ThemeManifest,
        registry::{ThemeEntry, ThemeRegistry},
        resolved::ResolvedTheme,
        settings::ThemeSettings,
    },
};

pub use disk::DiskThemeRepository;

/// Errors produced during repository and persistence operations.
#[derive(Debug, Error)]
pub enum ThemeError {
    /// I/O error carrying the path and root cause.
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Resolve error: {0}")]
    Resolved(String),

    /// Requested theme identifier was not found.
    #[error("theme '{0}' not found")]
    NotFound(ThemeId),

    /// Requested variant was not found in the theme manifest.
    #[error("variant '{variant}' not found in theme '{theme}'")]
    NoSuchVariant { theme: ThemeId, variant: VariantId },

    /// Manifest parsing or validation error.
    #[error("manifest error: {0}")]
    Manifest(#[from] ManifestError),

    /// Registry parsing or validation error.
    #[error("registry error: {0}")]
    Registry(#[from] RegistryError),

    /// Settings parsing or validation error.
    #[error("settings error: {0}")]
    Settings(#[from] SettingsError),

    /// Resolved payload parsing or structure error.
    #[error("resolved payload error: {0}")]
    Backend(#[from] BackendError),

    #[error(transparent)]
    IdError(#[from] IdError),

    /// Schema version is unsupported.
    #[error("unsupported schema version {found}, supported {supported}")]
    SchemaUnsupported { found: u32, supported: u32 },

    /// Serialization or deserialization failure.
    #[error("serialization error: {0}")]
    Serialization(String),
}

/// Abstract theme repository for loading manifests, resolving variants, and managing registries.
#[async_trait]
pub trait ThemeRepository: Send + Sync {
    /// Loads the manifest for the given theme identifier.
    async fn manifest(&self, id: &ThemeId) -> Result<ThemeManifest, ThemeError>;

    /// Returns the registry entry for the given theme identifier, if present.
    async fn entry(&self, id: &ThemeId) -> Result<Option<ThemeEntry>, ThemeError>;

    /// Lists all installed theme identifiers.
    async fn list(&self) -> Result<Vec<ThemeId>, ThemeError>;

    /// Loads the authoritative theme registry (`themes.toml`).
    async fn load_registry(&self) -> Result<ThemeRegistry, ThemeError>;

    /// Atomically persists the theme registry to disk.
    async fn save_registry(&self, reg: &ThemeRegistry) -> Result<(), ThemeError>;

    /// Loads user settings, recovering to defaults when the file is missing or corrupt.
    async fn load_settings(&self) -> Result<ThemeSettings, ThemeError>;

    /// Atomically persists user settings to disk.
    async fn save_settings(&self, settings: &ThemeSettings) -> Result<(), ThemeError>;

    /// Resolves a theme variant into an authoritative [`ResolvedTheme`].
    async fn resolve_variant(
        &self,
        id: &ThemeId,
        variant: &VariantId,
    ) -> Result<ResolvedTheme, ThemeError>;

    /// Rebuilds the theme registry by rescanning directories on disk.
    async fn rebuild_registry(&self) -> Result<ThemeRegistry, ThemeError>;
}
