//! # KDE Color Integration
//!
//! Generates the `kdeglobals` color groups, the window decoration group, and
//! the generation-scoped Plasma color scheme from semantic [`ColorRoles`].
//!
//! The adapter is split by concern: [`paths`] owns the on-disk layout and the
//! superseded-scheme detection, [`color`] maps Material roles onto KDE color
//! groups, [`globals`] renders and merges `kdeglobals`, [`scheme`] renders the
//! standalone `.colors` scheme, and this module wires them into the [`Adapter`]
//! implementation.

mod color;
mod globals;
mod paths;
mod scheme;

#[cfg(test)]
mod tests;

use std::path::PathBuf;

use crate::{
    backend::{Adapter, BackendError, BackendOutput},
    domain::resolved::ResolvedTheme,
};

use self::globals::read_optional;

pub use self::{
    globals::{merge_kdeglobals, render_kdeglobals},
    paths::{color_scheme_path, color_schemes_dir, kdeglobals_path},
    scheme::{
        KDE_COLOR_SCHEME_EXTENSION, KDE_COLOR_SCHEME_NAME, KDE_COLOR_SCHEMES_DIR,
        kde_color_scheme_name, render_color_scheme,
    },
};

/// Adapter name registered with the adapter registry and reported in logs.
pub const KDE_ADAPTER_NAME: &str = "kde";

/// Key naming the `kdeglobals` artifact in backend status reports.
pub const KDE_GLOBALS_PATH_KEY: &str = "kde_globals";

/// Key naming the Plasma color scheme artifact in backend status reports.
pub const KDE_COLOR_SCHEME_PATH_KEY: &str = "kde_color_scheme";

/// Backend adapter emitting the KDE color scheme and config fragments.
#[derive(Debug, Clone)]
pub struct KdeAdapter {
    /// XDG config home holding `kdeglobals`.
    pub(crate) config_home: PathBuf,

    /// XDG data home holding the `color-schemes/` directory.
    pub(crate) data_home: PathBuf,

    /// Generation-scoped name of the scheme this adapter installs.
    pub(crate) kde_color_scheme_name: String,
}

impl KdeAdapter {
    /// Constructs a new [`KdeAdapter`].
    ///
    /// # Parameters
    /// - `config_home`: XDG config home (`~/.config` by default). KDE applications
    ///   read colors from `kdeglobals` here.
    /// - `data_home`: XDG data home (`~/.local/share` by default). The scheme is
    ///   installed under `color-schemes/`, where Plasma looks it up.
    #[must_use]
    pub fn new(config_home: PathBuf, data_home: PathBuf) -> Self {
        Self {
            config_home,
            data_home,
            kde_color_scheme_name: KDE_COLOR_SCHEME_NAME.to_string(),
        }
    }
}

impl Adapter for KdeAdapter {
    fn name(&self) -> &'static str {
        KDE_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        // Step 1: Merge into the real kdeglobals so the user's other settings
        // survive a theme change. A missing or empty file is generated whole.
        let globals_path = self.kdeglobals_path();
        let existing = read_optional(&globals_path);
        let globals = if existing.trim().is_empty() {
            render_kdeglobals(&theme.colors)
        } else {
            merge_kdeglobals(&existing, &theme.colors)
        };

        // Step 2: Install the scheme Plasma applies at startup and on change.
        // The name carries the generation, so the desktop can tell a regenerated
        // palette apart from the one it already applied.
        let scheme = render_color_scheme(&theme.colors, &self.kde_color_scheme_name);

        // Step 3: Report the scheme of the previous generation for deletion. The
        // caller removes it only after the new scheme is durable on disk.
        let removals = self.stale_color_schemes();

        Ok(BackendOutput {
            files: vec![
                (globals_path, globals.into_bytes()),
                (self.color_scheme_path(), scheme.into_bytes()),
            ],
            env: Vec::new(),
            removals,
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.kde_color_scheme_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.kde_color_scheme_name.clone()
    }
}
