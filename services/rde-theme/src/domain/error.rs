//! # Domain Error Types
//!
//! Re-exports all domain layer error types.

pub use crate::domain::{
    identity::IdError, manifest::ManifestError, registry::RegistryError, resolved::ColorError,
    settings::SettingsError,
};
