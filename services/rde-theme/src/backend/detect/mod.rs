pub(super) mod gtk;
pub(super) mod qt;

use std::{env, path::PathBuf};

use crate::{
    backend::detect::{gtk::GtkEnv, qt::QtEnv},
    paths::{xdg_config_home, xdg_data_home},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DesktopKind {
    Kde,
    Gnome,
    LxQt,
    Deepin,
    Hyprland,
    Sway,
    Other,
}

pub struct SessionEnv {
    pub(super) desktop: DesktopKind,
    pub qt: QtEnv,
    pub gtk: GtkEnv,
    pub config_home: PathBuf,
    pub data_home: PathBuf,
}

impl SessionEnv {
    /// Read XDG_*, QT_QPA_PLATFORMTHEME, check plugin paths.
    /// Called exactly once, from app.rs. Never called again.
    /// Infallible: missing environment is a default, not an error.
    pub fn detect() -> Self {
        Self {
            desktop: detect_desktop(),
            qt: QtEnv::detect_qt(),
            gtk: GtkEnv::detect_gtk(),
            config_home: xdg_config_home(),
            data_home: xdg_data_home(),
        }
    }

    pub fn is_kde(&self) -> bool {
        self.desktop == DesktopKind::Kde
    }
    pub fn is_gnome(&self) -> bool {
        self.desktop == DesktopKind::Gnome
    }
    pub fn is_lxqt(&self) -> bool {
        self.desktop == DesktopKind::LxQt
    }
    pub fn is_deepin(&self) -> bool {
        self.desktop == DesktopKind::Deepin
    }
    pub fn is_hyprland(&self) -> bool {
        self.desktop == DesktopKind::Hyprland
    }

    /// True iff the session has no desktop palette of its own.
    /// Hyprland / Sway / unrecognized compositors: true.
    /// KDE / GNOME / LXQt / Deepin: false (they have desktop palettes).
    pub fn is_compositor(&self) -> bool {
        matches!(
            self.desktop,
            DesktopKind::Hyprland | DesktopKind::Sway | DesktopKind::Other
        )
    }

    /// The raw desktop kind, for diagnostics and D-Bus properties.
    pub fn desktop_kind(&self) -> DesktopKind {
        self.desktop
    }
}

fn detect_desktop() -> DesktopKind {
    let raw = env::var("XDG_CURRENT_DESKTOP")
        .or_else(|_| env::var("XDG_SESSION_DESKTOP"))
        .or_else(|_| env::var("DESKTOP_SESSION"))
        .unwrap_or_default()
        .to_uppercase();

    if raw.contains("KDE") || raw.contains("PLASMA") {
        DesktopKind::Kde
    } else if raw.contains("GNOME") {
        DesktopKind::Gnome
    } else if raw.contains("LXQT") {
        DesktopKind::LxQt
    } else if raw.contains("DEEPIN") || raw.contains("DDE") {
        DesktopKind::Deepin
    } else if raw.contains("HYPR") {
        DesktopKind::Hyprland
    } else if raw.contains("SWAY") {
        DesktopKind::Sway
    } else {
        DesktopKind::Other
    }
}
