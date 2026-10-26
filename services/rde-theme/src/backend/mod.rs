//! # Backend Adapters and Color Schemes
//!
//! Provides the [`Backend`] trait and toolkit emitters (GTK, Qt/KDE, Material 3).
//!
//! Backends are pure string/byte builders that return paths and payloads.
//! File writes are performed exclusively by the application layer.

use std::path::PathBuf;
use thiserror::Error;

use crate::domain::resolved::ResolvedTheme;

pub mod gtk;
pub mod material;
pub mod qt;

pub use gtk::GtkEmitter;
pub use material::{FALLBACK_SEED_COLOR, MATERIAL_ALGORITHM_VERSION, compute_color_roles};
pub use qt::{KDE_COLOR_SCHEME_NAME, QtEmitter};

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

/// Output payload emitted by a [`Backend`].
#[derive(Debug, Clone, Default)]
pub struct BackendOutput {
    /// Files to be atomically persisted: `(absolute_path, content_bytes)`.
    pub files: Vec<(PathBuf, Vec<u8>)>,

    /// Environment variables to set in the daemon and child processes.
    pub env: Vec<(String, String)>,
}

/// A toolkit or environment emitter that renders a [`ResolvedTheme`].
pub trait Backend: Send + Sync {
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
}
