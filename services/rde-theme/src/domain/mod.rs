//! # Pure Domain Models
//!
//! Pure theme domain logic and models: validated identifiers, author-owned manifests,
//! factual registries, user preferences, and interop payloads.
//!
//! This layer depends only on `std`, `serde`, and `thiserror`.

pub mod error;
pub mod identity;
pub mod manifest;
pub mod registry;
pub mod resolved;
pub mod settings;
pub mod validation;

pub use identity::{IdError, ThemeId, VariantId};
pub use manifest::{
    BUILTIN_DYNAMIC_VARIANT_DIR, ContrastLevel, MAX_VARIANT_FILE_SIZE_BYTES, ManifestError,
    RelativePath, SUPPORTED_MANIFEST_SCHEMA_VERSION, ThemeManifest, ThemeMode, VariantDescriptor,
};
pub use registry::{
    RegistryError, SUPPORTED_REGISTRY_SCHEMA_VERSION, ThemeEntry, ThemeLocation, ThemeRegistry,
    ThemeSource,
};
pub use resolved::{
    Color, ColorError, ColorRoles, ColorSeeds, DEFAULT_ERROR_SEED, FALLBACK_SEED_COLOR, Motion,
    ResolvedTheme, SUPPORTED_RESOLVED_SCHEMA_VERSION, Shape, Typography, VariantKind,
};
pub use settings::{
    DynamicSettings, DynamicThemeUpdate, SUPPORTED_SETTINGS_SCHEMA_VERSION, SettingsError,
    ThemeSettings,
};
pub use validation::{
    FileInspector, validate_manifest_pure, validate_registry_pure, validate_settings,
};
