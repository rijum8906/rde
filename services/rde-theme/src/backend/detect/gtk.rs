use std::path::PathBuf;

use crate::paths::xdg_config_home;

#[derive(Debug, Clone)]
pub struct GtkEnv {
    /// Major GTK version detected, or None if GTK isn't present.
    pub gtk_version: Option<u8>,

    /// Paths where the GTK settings files live, for the adapter.
    pub gtk3_settings: PathBuf,
    pub gtk4_settings: PathBuf,

    /// Whether the GTK3 config directory exists (i.e. GTK3 apps have run).
    pub gtk3_configured: bool,
    pub gtk4_configured: bool,
}

impl GtkEnv {
    pub fn detect_gtk() -> GtkEnv {
        let config_home = xdg_config_home();

        let gtk3_settings = config_home.join("gtk-3.0/settings.ini");
        let gtk4_settings = config_home.join("gtk-4.0/settings.ini");

        let gtk3_configured = gtk3_settings.exists();
        let gtk4_configured = gtk4_settings.exists();

        // Version detection: prefer the runtime library (what GTK apps
        // actually link against), fall back to the config dirs.
        let gtk_version = detect_gtk_runtime().or({
            match (gtk3_configured, gtk4_configured) {
                (false, true) => Some(4),
                (true, false) => Some(3),
                (true, true) => Some(4), // both present → assume GTK4 default
                (false, false) => None,  // neither → GTK not in use
            }
        });

        GtkEnv {
            gtk_version,
            gtk3_settings,
            gtk4_settings,
            gtk3_configured,
            gtk4_configured,
        }
    }
}

/// Check whether libgtk-4.so / libgtk-3.so is present via `ldconfig -p`.
/// This is a cheap, cached check; it doesn't dlopen.
fn detect_gtk_runtime() -> Option<u8> {
    let output = std::process::Command::new("ldconfig")
        .arg("-p")
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    if text.contains("libgtk-4.so") {
        Some(4)
    } else if text.contains("libgtk-3.so") {
        Some(3)
    } else {
        None
    }
}
