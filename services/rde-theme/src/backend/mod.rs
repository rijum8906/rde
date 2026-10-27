//! # Backend Adapters and Color Schemes
//!
//! Provides the [`Backend`] trait and toolkit emitters (GTK, Qt/KDE, Material 3).
//!
//! Backends are pure string/byte builders that return paths and payloads.
//! File writes are performed exclusively by the application layer.

use std::{collections::HashMap, path::PathBuf};
use thiserror::Error;

pub mod adapter;
pub mod detect;
pub mod gtk;
pub mod kde;
pub mod material;
pub mod qt;
pub mod registry;
pub mod resolver;
pub mod resolvers;

pub use gtk::GtkEmitter;
pub use kde::{KDE_COLOR_SCHEME_NAME, KdeAdapter};
pub use material::{FALLBACK_SEED_COLOR, MATERIAL_ALGORITHM_VERSION, compute_color_roles};
pub use qt::QtAdapter;

use crate::{
    domain::{
        ResolvedTheme,
        identity::{AdapterId, ThemeId, VariantId},
    },
    paths::{xdg_cache_home, xdg_config_home, xdg_data_home},
};

/// Errors produced during backend rendering.
#[derive(Debug, Error)]
pub enum BackendError {
    /// Failed to render backend output.
    #[error("failed to render backend '{backend}': {message}")]
    Render {
        backend: &'static str,
        message: String,
    },

    /// I/O error occurred during asset processing.
    #[error("I/O error during backend processing: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, Default)]
pub enum BackendKind {
    Gtk,
    Qt,
    #[default]
    Material,
}

/// Output payload emitted by a [`Backend`].
#[derive(Debug, Clone, Default)]
pub struct BackendOutput {
    /// Files to be atomically persisted: `(absolute_path, content_bytes)`.
    pub files: Vec<(PathBuf, Vec<u8>)>,

    /// Environment variables to set in the daemon and child processes.
    pub env: Vec<(String, String)>,

    /// Outputs of earlier generations this payload supersedes.
    ///
    /// The application layer deletes them only after `files` is durable, so a
    /// regenerated palette always replaces the previous one instead of
    /// accumulating one artifact per publication. Adapters must list paths they
    /// generated themselves; user-owned files are never listed.
    pub removals: Vec<PathBuf>,
}

/// Builds the unique, generation-scoped name shared by every themed surface.
///
/// # Parameters
/// - `theme_id`: identifier of the published theme
/// - `variant_id`: identifier of the published variant
/// - `generation`: publication generation the name belongs to
///
/// # Returns
/// `"<theme>-<variant>-v<generation>"`, for example `rde-dynamic-dark-v7`. Both
/// identifiers already satisfy the `[a-z0-9-]` grammar, so the result is a safe
/// file stem and a safe `plasma-apply-colorscheme` argument.
#[must_use]
pub fn unique_theme_name(theme_id: &ThemeId, variant_id: &VariantId, generation: u32) -> String {
    format!("{theme_id}-{variant_id}-v{generation}")
}

/// A toolkit or environment emitter that renders a [`ResolvedTheme`].
pub trait Adapter: Send + Sync {
    fn name(&self) -> &'static str;

    /// Renders configuration files and environment definitions for the theme.
    ///
    /// # Parameters
    /// - `theme`: fully-resolved theme payload
    ///
    /// # Errors
    /// Returns [`BackendError`] if rendering fails.
    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError>;

    fn set_unique_theme_name(&mut self, theme_name: String);
    fn unique_theme_name(&self) -> String;
}

#[derive(Default)]
pub struct AdapterRegistry {
    pub adapters: HashMap<AdapterId, Box<dyn Adapter>>,
}

impl AdapterRegistry {
    pub fn build() -> Self {
        let mut adapters: HashMap<AdapterId, Box<dyn Adapter>> = HashMap::new();

        // KDE reads `kdeglobals` from the XDG config root and looks color schemes
        // up under `color-schemes/` in the XDG data home, so the Qt adapter
        // targets those roots instead of the rde theme subdirectories.
        let config_home = xdg_config_home();
        let data_home = xdg_data_home();
        let cache_dir = xdg_cache_home().join("rde/theme");

        // Step 1: Register each adapter under its identifier. An identifier that
        // fails the grammar cannot be produced by this build's constants, so a
        // malformed one is skipped with a log instead of panicking the service.
        let kde = KdeAdapter::new(config_home.clone(), data_home);
        let qt = QtAdapter::new(config_home);
        let gtk = GtkEmitter::new(cache_dir);

        for adapter in [
            Box::new(kde) as Box<dyn Adapter>,
            Box::new(qt),
            Box::new(gtk),
        ] {
            match AdapterId::new(adapter.name()) {
                Ok(id) => {
                    adapters.insert(id, adapter);
                }
                Err(err) => {
                    tracing::warn!(
                        adapter = %adapter.name(),
                        error = %err,
                        "Skipping adapter with an invalid identifier"
                    );
                }
            }
        }

        Self { adapters }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unique_theme_name_carries_theme_variant_and_generation() {
        let ocean = ThemeId::new("ocean").unwrap();
        let contrast = VariantId::new("dark-high-contrast").unwrap();
        assert_eq!(
            unique_theme_name(&ocean, &contrast, 12),
            "ocean-dark-high-contrast-v12"
        );

        let dynamic = ThemeId::builtin_dynamic();
        let light = VariantId::new("light").unwrap();
        assert_eq!(
            unique_theme_name(&dynamic, &light, 1),
            "rde-dynamic-light-v1"
        );
    }

    #[test]
    fn unique_theme_name_changes_with_every_generation() {
        let theme = ThemeId::new("ocean").unwrap();
        let variant = VariantId::new("dark").unwrap();

        // A regeneration must never reuse the name the desktop already loaded.
        assert_ne!(
            unique_theme_name(&theme, &variant, 4),
            unique_theme_name(&theme, &variant, 5)
        );
    }
}
