//! # GTK Theme Backend
//!
//! Emits GTK 3/4 CSS overrides and environment settings.

pub mod css;

use crate::{
    backend::{Backend, BackendError, BackendOutput},
    domain::resolved::ResolvedTheme,
};
pub use css::render_gtk_css;
use std::path::PathBuf;

/// Backend adapter that writes GTK CSS color definitions.
#[derive(Debug, Clone)]
pub struct GtkEmitter {
    cache_dir: PathBuf,
}

impl GtkEmitter {
    /// Constructs a new [`GtkEmitter`] targeting the given theme cache directory.
    #[must_use]
    pub fn new(cache_dir: PathBuf) -> Self {
        Self { cache_dir }
    }
}

impl Backend for GtkEmitter {
    fn name(&self) -> &'static str {
        "gtk"
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        let css = render_gtk_css(&theme.colors);
        let target_file = self.cache_dir.join("gtk.css");

        // Set GTK_THEME environment variable if needed.
        let env = Vec::new();

        Ok(BackendOutput {
            files: vec![(target_file, css.into_bytes())],
            env,
        })
    }
}
