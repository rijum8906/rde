use std::env;
use std::path::PathBuf;

use crate::paths::xdg_data_home;

#[derive(Debug, Clone)]
pub struct QtEnv {
    /// Value of QT_QPA_PLATFORMTHEME, if set and non-empty.
    pub platform_theme: Option<String>,

    /// True iff the qt6ct Qt6 platform theme plugin is on disk.
    pub qt6ct_plugin_installed: bool,

    /// True iff the qt5ct Qt5 platform theme plugin is on disk.
    pub qt5ct_plugin_installed: bool,

    /// True iff QT_QPA_PLATFORMTHEME names a plugin that is installed.
    /// This is the "will writes to qt6ct.conf actually be read?" answer.
    pub platform_theme_effective: bool,
}

impl QtEnv {
    pub fn detect_qt() -> QtEnv {
        // Step 1: read the variable. Empty string is the same as unset —
        // Qt treats "" as "no platform theme", so we do too.
        let platform_theme = env::var("QT_QPA_PLATFORMTHEME")
            .ok()
            .filter(|s| !s.is_empty());

        // Step 2: find the plugin directories. Qt looks in several places;
        // the ones that matter are the ones the distro actually uses.
        let plugin_dirs = qt_plugin_dirs();

        // Step 3: probe the actual plugin files, not the config directories.
        let qt6ct_plugin_installed = plugin_file_exists(&plugin_dirs, "libqt6ct.so")
            || plugin_file_exists(&plugin_dirs, "libqt6ct-plugin.so");

        let qt5ct_plugin_installed = plugin_file_exists(&plugin_dirs, "libqt5ct.so")
            || plugin_file_exists(&plugin_dirs, "libqt5ct-plugin.so");

        // Step 4: the honest answer to "is the configured theme actually loadable?"
        let platform_theme_effective = match platform_theme.as_deref() {
            Some("qt6ct") => qt6ct_plugin_installed,
            Some("qt5ct") => qt5ct_plugin_installed,
            Some("kde") => true, // shipped with Plasma, always present
            Some("gtk3") | Some("gtk4") | Some("gtk") => true,
            Some(_) => false, // unknown name
            None => false,    // no theme configured
        };

        QtEnv {
            platform_theme,
            qt6ct_plugin_installed,
            qt5ct_plugin_installed,
            platform_theme_effective,
        }
    }
}

/// Directories Qt looks in for platform theme plugins. Order is priority.
fn qt_plugin_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();

    // 1. Explicit override — Qt checks this first.
    if let Ok(p) = env::var("QT_PLUGIN_PATH") {
        dirs.extend(env::split_paths(&p).map(|d| d.join("platformthemes")));
    }

    // 2. System plugin dirs. These are distro-dependent; check the
    //    common layouts rather than hardcoding one.
    for base in [
        "/usr/lib/qt6/plugins",
        "/usr/lib/x86_64-linux-gnu/qt6/plugins",
        "/usr/lib64/qt6/plugins",
        "/usr/lib/qt5/plugins",
        "/usr/lib/x86_64-linux-gnu/qt5/plugins",
    ] {
        dirs.push(PathBuf::from(base).join("platformthemes"));
    }

    // 3. User-local plugin dir.
    let data = xdg_data_home();

    dirs.push(data.join("qt6/plugins/platformthemes"));

    dirs
}

fn plugin_file_exists(dirs: &[PathBuf], name: &str) -> bool {
    dirs.iter().any(|d| d.join(name).exists())
}
