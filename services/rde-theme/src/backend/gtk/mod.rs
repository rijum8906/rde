//! # GTK Theme Backend
//!
//! Emits GTK 3/4 CSS overrides and environment settings.

pub mod css;

use crate::{
    backend::{Adapter, BackendError, BackendOutput},
    domain::resolved::ResolvedTheme,
};
pub use css::render_gtk_css;
use std::path::PathBuf;

pub const GTK_ADAPTER_NAME: &str = "gtk";
pub const GTK_THEME_NAME: &str = "rde-gtk-m3";

/// Backend adapter that writes GTK CSS color definitions.
#[derive(Debug, Clone)]
pub struct GtkEmitter {
    cache_dir: PathBuf,
    gtk_theme_name: String,
}

impl GtkEmitter {
    /// Constructs a new [`GtkEmitter`] targeting the given theme cache directory.
    #[must_use]
    pub fn new(cache_dir: PathBuf) -> Self {
        Self {
            cache_dir,
            gtk_theme_name: GTK_THEME_NAME.to_string(),
        }
    }
}

impl Adapter for GtkEmitter {
    fn name(&self) -> &'static str {
        GTK_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        let css = render_gtk_css(&theme.colors);
        let target_file = self.cache_dir.join("gtk.css");

        // Set GTK_THEME environment variable if needed.
        let env = Vec::new();

        Ok(BackendOutput {
            files: vec![(target_file, css.into_bytes())],
            env,
            // GTK reads the single `gtk.css` override in place, so a publication
            // supersedes no other file.
            removals: Vec::new(),
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.gtk_theme_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.gtk_theme_name.clone()
    }
}
