//! # qt5ct / qt6ct Paths
//!
//! Owns the on-disk layout of the Qt configuration tools and the detection of
//! palettes that a previous publication generation left behind.

use std::path::PathBuf;

use super::QtAdapter;

/// Subdirectory of a qt5ct/qt6ct config directory that holds palettes.
const QTCT_COLORS_DIR: &str = "colors";

/// File extension of both qt5ct/qt6ct palettes and their config files.
const QTCT_EXTENSION: &str = "conf";

/// One of the two supported Qt configuration tools.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum QtTool {
    Qt5,
    Qt6,
}

impl QtTool {
    /// Both tools, in write order.
    pub(crate) const ALL: [QtTool; 2] = [QtTool::Qt5, QtTool::Qt6];

    /// Directory name below the XDG config home, which doubles as the config
    /// file stem (`qt5ct/qt5ct.conf`).
    pub(crate) fn name(self) -> &'static str {
        match self {
            QtTool::Qt5 => "qt5ct",
            QtTool::Qt6 => "qt6ct",
        }
    }
}

impl QtAdapter {
    /// Whether the adapter should write for [tool].
    pub(crate) fn is_enabled(&self, tool: QtTool) -> bool {
        match tool {
            QtTool::Qt5 => self.qt5ct,
            QtTool::Qt6 => self.qt6ct,
        }
    }

    /// Config directory of [tool] (`~/.config/qt5ct` or `~/.config/qt6ct`).
    pub(crate) fn tool_dir(&self, tool: QtTool) -> PathBuf {
        self.config_home.join(tool.name())
    }

    /// Config file of [tool] (`qt5ct.conf` or `qt6ct.conf`).
    pub(crate) fn config_path(&self, tool: QtTool) -> PathBuf {
        self.tool_dir(tool)
            .join(format!("{}.{QTCT_EXTENSION}", tool.name()))
    }

    /// Palette file installed for [tool] in the current generation.
    pub(crate) fn palette_path(&self, tool: QtTool) -> PathBuf {
        self.tool_dir(tool)
            .join(QTCT_COLORS_DIR)
            .join(format!("{}.{QTCT_EXTENSION}", self.palette_name))
    }

    /// Lists palettes generated for the same theme and variant by an earlier
    /// publication generation.
    ///
    /// # Returns
    /// Absolute paths of superseded `<theme>-<variant>-v<generation>.conf`
    /// files. Palettes the user installed and the palette of the current
    /// generation are excluded, so the caller can delete the result
    /// unconditionally.
    pub(crate) fn stale_palettes(&self, tool: QtTool) -> Vec<PathBuf> {
        // Step 1: Split the generation off the current name. `rsplit_once` takes
        // the last `-v`, so theme and variant ids containing `-v` stay intact.
        let Some((prefix, _)) = self.palette_name.rsplit_once("-v") else {
            return Vec::new();
        };
        let generated = format!("{prefix}-v");
        let current = self.palette_path(tool);

        // Step 2: A missing colors directory means nothing was generated yet.
        let Ok(entries) = std::fs::read_dir(self.tool_dir(tool).join(QTCT_COLORS_DIR)) else {
            return Vec::new();
        };

        // Step 3: Keep only files this service generated for an older generation.
        entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                if path == &current
                    || path.extension().and_then(|ext| ext.to_str()) != Some(QTCT_EXTENSION)
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
