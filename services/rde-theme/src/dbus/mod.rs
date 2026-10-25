//! # D-Bus Service Integration
//!
//! Exposes `org.rde.Theme` and Freedesktop Settings portal over the session bus.

pub mod iface;

pub use iface::{
    PORTAL_INTERFACE_NAME, PORTAL_OBJECT_PATH, PortalSettingsInterface, THEME_INTERFACE_NAME,
    THEME_OBJECT_PATH, ThemeInterface, spawn_dbus_signal_broadcaster,
};
