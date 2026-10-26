//! # Backend Adapters and Color Schemes
//!
//! Provides the [`Backend`] trait and toolkit emitters (GTK, Qt/KDE, Material 3).
//!
//! Backends are pure string/byte builders that return paths and payloads.
//! File writes are performed exclusively by the application layer.

use rde_core::fs::rde_service_data_dir;
use std::{collections::HashMap, path::PathBuf};
use thiserror::Error;

pub mod adapter;
pub mod detect;
pub mod gtk;
pub mod material;
pub mod qt;
pub mod registry;
pub mod resolver;
pub mod resolvers;

pub use gtk::GtkEmitter;
pub use material::{FALLBACK_SEED_COLOR, MATERIAL_ALGORITHM_VERSION, compute_color_roles};
pub use qt::{KDE_COLOR_SCHEME_NAME, QtEmitter};

use crate::{
    constants::SERVICE_NAME,
    domain::{ResolvedTheme, identity::AdapterId},
    paths::{xdg_cache_home, xdg_config_home},
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
}

/// A toolkit or environment emitter that renders a [`ResolvedTheme`].
pub trait Adapter: Send + Sync {
    /// Unique name of the backend adapter (e.g. `"gtk"`, `"qt"`).
    fn name(&self) -> &'static str;

    /// Renders configuration files and environment definitions for the theme.
    ///
    /// # Parameters
    /// - `theme`: fully-resolved theme payload
    ///
    /// # Errors
    /// Returns [`BackendError`] if rendering fails.
    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError>;

    fn config_paths(&self) -> HashMap<String, PathBuf>;
}

#[derive(Default)]
pub struct AdapterRegistry {
    pub adapters: HashMap<AdapterId, Box<dyn Adapter>>,
}

impl AdapterRegistry {
    pub fn build() -> Self {
        let mut adapters: HashMap<AdapterId, Box<dyn Adapter>> = HashMap::new();

        let config_home = xdg_config_home().join("rde/theme/");
        let data_home = rde_service_data_dir(SERVICE_NAME).unwrap();
        let cache_dir = xdg_cache_home().join("rde/theme");

        // Qt
        let qt = QtEmitter::new(config_home, data_home);
        adapters.insert(AdapterId::new(qt.name().to_string()).unwrap(), Box::new(qt));

        // Gtk
        let gtk = GtkEmitter::new(cache_dir);
        adapters.insert(
            AdapterId::new(gtk.name().to_string()).unwrap(),
            Box::new(gtk),
        );

        Self { adapters }
    }
}
