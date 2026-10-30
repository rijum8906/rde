//! # GTK Paths and Superseded Generations
//!
//! Owns the on-disk layout GTK reads (`<config>/gtk-{3,4}.0/settings.ini`) and
//! the versioned CSS trees this adapter publishes into the cache.

use std::path::PathBuf;

use super::GtkEmitter;

/// File name of the stylesheet inside a generation directory.
const CSS_FILE: &str = "gtk.css";

/// File name of the toolkit settings document.
const SETTINGS_FILE: &str = "settings.ini";

/// One of the two supported GTK major versions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum GtkTool {
    Gtk3,
    Gtk4,
}

impl GtkTool {
    /// Both toolkits, in write order.
    pub(crate) const ALL: [GtkTool; 2] = [GtkTool::Gtk3, GtkTool::Gtk4];

    /// Directory name below the XDG config home (`gtk-3.0`, `gtk-4.0`).
    ///
    /// The same name is used as the path segment below the cache root.
    pub(crate) fn name(self) -> &'static str {
        match self {
            GtkTool::Gtk3 => "gtk-3.0",
            GtkTool::Gtk4 => "gtk-4.0",
        }
    }

    /// Directory name below the XDG config home.
    ///
    /// Kept as a named accessor so the config side stays readable even if the
    /// cache layout ever diverges from the config layout.
    pub(crate) fn xdg_config_name(self) -> &'static str {
        self.name()
    }

    /// Key in `settings.ini` that switches GTK to the dark appearance.
    ///
    /// Both GTK major versions read the same key, so it lives on the type
    /// rather than on a variant.
    pub(crate) const fn settings_key_dark() -> &'static str {
        "gtk-application-prefer-dark-theme"
    }
}

impl GtkEmitter {
    /// Whether the adapter should write for [tool].
    pub(crate) fn is_enabled(&self, tool: GtkTool) -> bool {
        match tool {
            GtkTool::Gtk3 => self.gtk3,
            GtkTool::Gtk4 => self.gtk4,
        }
    }

    /// Cache directory of [tool], holding one directory per generation.
    pub(crate) fn tool_dir(&self, tool: GtkTool) -> PathBuf {
        self.cache_dir.join(tool.name())
    }

    /// `gtk.css` of the current generation for [tool].
    ///
    /// The path is versioned (`<cache>/gtk-3.0/rde-gtk-m3-v<generation>/gtk.css`)
    /// because GTK re-reads the theme when `gtk-theme-name` changes.
    pub(crate) fn css_path(&self, tool: GtkTool) -> PathBuf {
        self.tool_dir(tool)
            .join(&self.gtk_theme_name)
            .join(CSS_FILE)
    }

    /// `settings.ini` of [tool] (`~/.config/gtk-3.0/settings.ini`).
    pub(crate) fn settings_path(&self, tool: GtkTool) -> PathBuf {
        self.config_home
            .join(tool.xdg_config_name())
            .join(SETTINGS_FILE)
    }

    /// Lists the stylesheets generated for the same theme by an earlier
    /// publication generation.
    ///
    /// # Returns
    /// The `gtk.css` of every superseded `rde-gtk-m3-v<generation>` directory.
    /// The publication layer deletes files, so the file inside each directory
    /// is reported rather than the directory itself; the emptied directory is
    /// left behind.
    pub(crate) fn stale_css(&self, tool: GtkTool) -> Vec<PathBuf> {
        // Step 1: Split the generation off the current name. `rsplit_once` takes
        // the last `-v`, so theme ids containing `-v` stay intact.
        let Some((prefix, _)) = self.gtk_theme_name.rsplit_once("-v") else {
            return Vec::new();
        };
        let generated = format!("{prefix}-v");
        let current = self.tool_dir(tool).join(&self.gtk_theme_name);

        // Step 2: A missing tool directory means nothing was published yet.
        let Ok(entries) = std::fs::read_dir(self.tool_dir(tool)) else {
            return Vec::new();
        };

        // Step 3: Keep only the directories this service generated for an older
        // generation, and report the stylesheet inside each.
        entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                if path == &current || !path.is_dir() {
                    return false;
                }
                let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
                    return false;
                };
                name.strip_prefix(&generated).is_some_and(|generation| {
                    !generation.is_empty() && generation.bytes().all(|byte| byte.is_ascii_digit())
                })
            })
            .map(|directory| directory.join(CSS_FILE))
            .collect()
    }
}

/// Reports the session's GTK theme, if `gsettings` can answer.
///
/// A theme set at session level means GTK applications are running even when
/// neither toolkit has written its `settings.ini` yet, so both targets are
/// treated as installed.
pub(crate) fn session_gtk_theme() -> Option<String> {
    let output = std::process::Command::new("gsettings")
        .args(["get", "org.gnome.desktop.interface", "gtk-theme"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let theme = String::from_utf8_lossy(&output.stdout)
        .trim()
        .trim_matches('\'')
        .to_string();

    (!theme.is_empty()).then_some(theme)
}
