//! # GTK Theme Backend
//!
//! Emits a versioned `gtk.css` per GTK major version (`gtk-3.0`, `gtk-4.0`),
//! merges `gtk-theme-name` and `gtk-application-prefer-dark-theme` into each
//! tool's `settings.ini` while preserving every other key, sets `GTK_THEME` so
//! a running session picks up the new name, and reports the CSS of older
//! generations for deletion.
//!
//! The adapter is split by concern: [`paths`] owns the tool paths and the
//! superseded-generation detection, [`css`] renders the `@define-color`
//! stylesheet, [`settings`] merges `settings.ini`, and this module wires them
//! into the [`Adapter`] implementation.

pub mod css;
mod paths;
mod settings;

#[cfg(test)]
mod tests;

use std::path::PathBuf;

use crate::{
    backend::{Adapter, BackendError, BackendOutput},
    domain::resolved::ResolvedTheme,
};

pub use self::css::render_gtk_css;

use self::{
    paths::GtkTool,
    settings::{merge_settings_ini, prefers_dark, read_optional},
};

/// Adapter name registered with the adapter registry and reported in logs.
pub const GTK_ADAPTER_NAME: &str = "gtk";

/// Prefix of the generated GTK theme.
///
/// The published name is this prefix plus the publication generation
/// (`rde-gtk-m3-v<generation>`), so `gtk-theme-name` changes on every
/// publication and GTK reloads `gtk.css`.
pub const GTK_THEME_NAME: &str = "rde-gtk-m3";

/// Backend adapter that writes GTK CSS color definitions and their settings.
#[derive(Debug, Clone)]
pub struct GtkEmitter {
    /// XDG config home; `gtk-3.0/settings.ini` and `gtk-4.0/settings.ini` live
    /// below it.
    pub(crate) config_home: PathBuf,

    /// Root of the versioned CSS trees this adapter writes.
    pub(crate) cache_dir: PathBuf,

    /// Generation-scoped theme name consumed by `gtk-theme-name`.
    pub(crate) gtk_theme_name: String,

    /// Whether GTK 3 is present and should be themed.
    pub(crate) gtk3: bool,

    /// Whether GTK 4 is present and should be themed.
    pub(crate) gtk4: bool,
}

impl GtkEmitter {
    /// Constructs a new [`GtkEmitter`] that detects both GTK major versions.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home, where both `settings.ini` files live
    /// - `cache_dir`: root the versioned `gtk.css` trees are written under
    ///
    /// # Migration Note
    /// `config_home` was added as the first argument so the emitter can merge
    /// `settings.ini`; callers that previously passed only the cache directory
    /// must now pass the XDG config home first.
    #[must_use]
    pub fn new(config_home: PathBuf, cache_dir: PathBuf) -> Self {
        // Step 1: An existing config directory proves the toolkit has run on
        // this machine.
        let gtk3_dir = config_home.join(GtkTool::Gtk3.name()).is_dir();
        let gtk4_dir = config_home.join(GtkTool::Gtk4.name()).is_dir();

        // Step 2: A session-wide GTK theme also proves GTK apps run, even when
        // neither tool has written its config yet.
        let session_theme = paths::session_gtk_theme().is_some();

        Self::with_targets(
            config_home,
            cache_dir,
            gtk3_dir || session_theme,
            gtk4_dir || session_theme,
        )
    }

    /// Constructs the emitter with explicit tool availability.
    ///
    /// Used by [`GtkEmitter::new`] after detection and by tests that need a
    /// deterministic target set.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home holding both `settings.ini` files
    /// - `cache_dir`: root the versioned `gtk.css` trees are written under
    /// - `gtk3`: whether GTK 3 is present
    /// - `gtk4`: whether GTK 4 is present
    #[must_use]
    pub fn with_targets(config_home: PathBuf, cache_dir: PathBuf, gtk3: bool, gtk4: bool) -> Self {
        Self {
            config_home,
            cache_dir,
            gtk_theme_name: GTK_THEME_NAME.to_string(),
            gtk3,
            gtk4,
        }
    }
}

impl Adapter for GtkEmitter {
    fn name(&self) -> &'static str {
        GTK_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        let css = render_gtk_css(&theme.colors);
        let prefer_dark = prefers_dark(theme);
        let mut files = Vec::new();
        let mut removals = Vec::new();
        let mut env = Vec::new();

        for tool in GtkTool::ALL {
            // Step 1: Leave toolkits that are not installed untouched.
            if !self.is_enabled(tool) {
                continue;
            }

            // Step 2: Publish the CSS under the generation-scoped theme name.
            // GTK reloads `gtk.css` when `gtk-theme-name` changes, so a new
            // generation is a new directory and a new name.
            files.push((self.css_path(tool), css.clone().into_bytes()));

            // Step 3: Point the toolkit at it, preserving every other key.
            let settings_path = self.settings_path(tool);
            let existing = read_optional(&settings_path);
            files.push((
                settings_path,
                merge_settings_ini(&existing, &self.gtk_theme_name, prefer_dark).into_bytes(),
            ));

            // Step 4: Report the CSS of older generations for deletion.
            removals.extend(self.stale_css(tool));
        }

        // Step 5: Export the generated theme once, so newly launched GTK apps
        // start on the same name the settings file selects.
        if !files.is_empty() {
            env.push(("GTK_THEME".to_string(), self.gtk_theme_name.clone()));
        }

        Ok(BackendOutput {
            files,
            env,
            removals,
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.gtk_theme_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.gtk_theme_name.clone()
    }
}
