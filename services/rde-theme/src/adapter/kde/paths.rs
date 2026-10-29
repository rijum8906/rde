//! # KDE Paths and Superseded Schemes
//!
//! Owns the on-disk layout Plasma reads (`kdeglobals` in the XDG config home,
//! `color-schemes/` in the XDG data home) and the detection of schemes that a
//! previous publication generation left behind.

use std::path::{Path, PathBuf};

use super::{
    KdeAdapter,
    scheme::{KDE_COLOR_SCHEME_EXTENSION, KDE_COLOR_SCHEMES_DIR},
};

impl KdeAdapter {
    /// Path of the `kdeglobals` file KDE applications read.
    #[must_use]
    pub fn kdeglobals_path(&self) -> PathBuf {
        self.config_home.join("kdeglobals")
    }

    /// Path of the color scheme installed for Plasma.
    #[must_use]
    pub fn color_scheme_path(&self) -> PathBuf {
        color_scheme_path(&self.data_home, self.kde_color_scheme_name.clone())
    }

    /// Lists the color schemes generated for the same theme and variant by an
    /// earlier publication generation.
    ///
    /// # Returns
    ///
    /// Absolute paths of superseded `<theme>-<variant>-v<generation>.colors`
    /// files. The scheme of the current generation, schemes of other variants,
    /// and every scheme the user installed are excluded, so the caller can
    /// delete the result unconditionally.
    #[must_use]
    pub fn stale_color_schemes(&self) -> Vec<PathBuf> {
        // Step 1: Split the generation off the current name. `rsplit_once` takes
        // the last `-v`, so theme and variant ids containing `-v` stay intact.
        let Some((prefix, _)) = self.kde_color_scheme_name.rsplit_once("-v") else {
            return Vec::new();
        };
        let generated = format!("{prefix}-v");
        let current = self.color_scheme_path();

        // Step 2: A missing directory simply means nothing was generated yet.
        let Ok(entries) = std::fs::read_dir(color_schemes_dir(&self.data_home)) else {
            return Vec::new();
        };

        // Step 3: Keep only files this service generated for an older generation.
        entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                if path == &current
                    || path.extension().and_then(|ext| ext.to_str()) != Some("colors")
                {
                    return false;
                }
                let Some(stem) = path.file_stem().and_then(|stem| stem.to_str()) else {
                    return false;
                };
                stem.strip_prefix(&generated).is_some_and(|generation| {
                    !generation.is_empty() && generation.bytes().all(|byte| byte.is_ascii_digit())
                })
            })
            .collect()
    }
}

/// Path of the `kdeglobals` file KDE applications read.
pub fn kdeglobals_path(config_home: impl AsRef<Path>) -> PathBuf {
    config_home.as_ref().to_path_buf().join("kdeglobals")
}

/// Directory Plasma searches for installed color schemes.
pub fn color_schemes_dir(data_home: impl AsRef<Path>) -> PathBuf {
    data_home.as_ref().to_path_buf().join(KDE_COLOR_SCHEMES_DIR)
}

/// Path of the Plasma color scheme with [kde_color_scheme_name].
pub fn color_scheme_path(data_home: impl AsRef<Path>, kde_color_scheme_name: String) -> PathBuf {
    color_schemes_dir(data_home).join(format!(
        "{kde_color_scheme_name}.{KDE_COLOR_SCHEME_EXTENSION}"
    ))
}
