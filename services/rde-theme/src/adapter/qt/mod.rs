//! # Qt Platform Theme Integration
//!
//! Writes Material 3 palettes for qt5ct and qt6ct and selects them in each
//! tool's configuration when the platform theme is installed.
//!
//! The adapter is split by concern: [`paths`] owns the tool paths and the
//! superseded-palette detection, [`palette`] renders the `QPalette` color
//! groups, [`config`] merges the tool configuration, and this module wires
//! them into the [`Adapter`] implementation.

mod config;
mod palette;
mod paths;

#[cfg(test)]
mod tests;

use std::path::PathBuf;

use crate::{
    adapter::{Adapter, AdapterError, AdapterOutput},
    domain::resolved::ResolvedTheme,
};

use self::{
    config::{merge_qtct_config, read_optional},
    palette::render_qtct_palette,
    paths::QtTool,
};

/// Adapter name registered with the adapter registry and reported in logs.
pub const QT_ADAPTER_NAME: &str = "qt";

/// Name of the palette the service installs before the first publication.
///
/// Every publication replaces it with the generation-scoped name built by
/// [`crate::adapter::unique_theme_name`], so a regenerated palette lands at a
/// new path and qt5ct/qt6ct reload it instead of keeping the old one.
pub const QT_PALETTE_NAME: &str = "RdeM3";

/// Adapter emitting qt5ct and qt6ct palettes and their tool configs.
///
/// A tool is only touched when it is installed: either its platform theme
/// plugin was detected or its config directory already exists, which means the
/// user has run it at least once.
#[derive(Debug, Clone)]
pub struct QtAdapter {
    /// XDG config home both tools read their configuration from.
    pub(crate) config_home: PathBuf,

    /// Generation-scoped palette name written for both tools.
    pub(crate) palette_name: String,

    /// Whether qt5ct is installed and should be themed.
    pub(crate) qt5ct: bool,

    /// Whether qt6ct is installed and should be themed.
    pub(crate) qt6ct: bool,
}

impl QtAdapter {
    /// Constructs the adapter and detects the installed Qt configuration tools.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home (`~/.config` by default)
    #[must_use]
    pub fn new(config_home: PathBuf) -> Self {
        // Step 1: The platform theme plugin proves the tool exists.
        let (qt5ct_plugin, qt6ct_plugin) = crate::detect::qtct_plugins();

        // Step 2: An existing config directory also counts. It covers Qt builds
        // whose plugin lives outside the probed paths and tools that were run
        // with a different Qt version.
        let qt5ct = qt5ct_plugin || config_home.join(QtTool::Qt5.name()).is_dir();
        let qt6ct = qt6ct_plugin || config_home.join(QtTool::Qt6.name()).is_dir();

        Self::with_targets(config_home, qt5ct, qt6ct)
    }

    /// Constructs the adapter with explicit tool availability.
    ///
    /// Used by [`QtAdapter::new`] after detection and by tests that need a
    /// deterministic target set.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home
    /// - `qt5ct`: whether qt5ct is installed
    /// - `qt6ct`: whether qt6ct is installed
    #[must_use]
    pub fn with_targets(config_home: PathBuf, qt5ct: bool, qt6ct: bool) -> Self {
        Self {
            config_home,
            palette_name: QT_PALETTE_NAME.to_string(),
            qt5ct,
            qt6ct,
        }
    }
}

impl Adapter for QtAdapter {
    fn name(&self) -> &'static str {
        QT_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<AdapterOutput, AdapterError> {
        let mut files = Vec::new();
        let mut removals = Vec::new();
        let mut env: Vec<(String, String)> = Vec::new();

        for tool in QtTool::ALL {
            // Step 1: Leave tools that are not installed untouched.
            if !self.is_enabled(tool) {
                continue;
            }

            // Step 2: Install the palette under the generation-scoped name.
            let palette_path = self.palette_path(tool);
            files.push((
                palette_path.clone(),
                render_qtct_palette(&theme.colors).into_bytes(),
            ));

            // Step 3: Point the tool at it, preserving the user's other settings.
            let config_path = self.config_path(tool);
            let existing = read_optional(&config_path);
            files.push((
                config_path,
                merge_qtct_config(&existing, &palette_path).into_bytes(),
            ));

            // Step 4: Report the palettes of older generations for deletion.
            removals.extend(self.stale_palettes(tool));

            // QT_QPA_PLATFORMTHEME=qt6ct or qt5ct
            env.push(("QT_QPA_PLATFORMTHEME".into(), tool.name().into()));
        }

        Ok(AdapterOutput {
            files,
            env,
            removals,
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.palette_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.palette_name.clone()
    }
}
