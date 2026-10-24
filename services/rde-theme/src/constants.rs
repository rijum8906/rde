//! # Service Constants
//!
//! Compile-time configuration for the service lifecycle, theme database, D-Bus
//! contract, and supervision task.

use std::time::Duration;

/// Service name reported to the `rde-daemon` supervisor.
pub const SERVICE_NAME: &str = "theme";

/// Capabilities advertised during the registration handshake.
pub const CAPABILITIES: &[&str] = &["dynamic-palettes", "theme-store"];

/// Well-known D-Bus name owned by this service on the session bus.
pub const DBUS_SERVICE_NAME: &str = "org.rde.Theme";

/// Object path exposing `org.rde.Theme` on the session bus.
pub const DBUS_OBJECT_PATH: &str = "/org/rde/Theme";

/// Maximum number of attempts made when connecting to the supervision socket.
pub const MAX_SOCKET_CONN_RETRY_COUNT: u32 = 5;

/// Delay between supervision socket connection attempts, in milliseconds.
pub const SOCKET_CONN_RETRY_DELAY_MS: u64 = 2_000;

/// Maximum time spent waiting for the supervision task to stop on shutdown.
pub const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(2);

/// Directory holding the theme database, relative to the XDG data home.
///
/// Resolves to `$XDG_DATA_HOME/rde/rde-theme`, which is
/// `~/.local/share/rde/rde-theme` on a default configuration.
pub const DATA_HOME_SUBDIR: &str = "rde/rde-theme";

/// File name of the theme registry (active theme, scheme, installed list).
pub const REGISTRY_FILE_NAME: &str = "themes.toml";

/// Directory holding one subdirectory per installed theme.
pub const THEMES_DIR_NAME: &str = "themes";

/// File name of the per-theme manifest stored inside a theme directory.
pub const MANIFEST_FILE_NAME: &str = "theme.toml";

/// Schema version written to `themes.toml`.
pub const REGISTRY_SCHEMA_VERSION: u32 = 1;

/// Schema version written to a theme's `theme.toml`.
pub const MANIFEST_SCHEMA_VERSION: u32 = 1;

/// Identifier of the theme seeded into a fresh theme database.
pub const DEFAULT_THEME_ID: &str = "default";

/// Source color used to seed the built-in default theme (`#RRGGBB`).
pub const DEFAULT_THEME_SOURCE_COLOR: &str = "#6DD6DA";

/// Source color of the built-in default theme as packed ARGB.
///
/// Kept in sync with [`DEFAULT_THEME_SOURCE_COLOR`] so the fallback palette can
/// be built without a fallible string parse.
pub const DEFAULT_THEME_SOURCE_COLOR_ARGB: u32 = 0xFF6D_D6DA;

/// Human-readable name of the built-in default theme.
pub const DEFAULT_THEME_DISPLAY_NAME: &str = "Default";

/// Description written into the built-in default theme manifest.
pub const DEFAULT_THEME_DESCRIPTION: &str =
    "Built-in RDE theme generated from the shipped source color.";

/// Version written into freshly generated theme manifests.
pub const DEFAULT_THEME_VERSION: &str = "1.0.0";

/// Maximum accepted length of a theme identifier.
pub const MAX_THEME_ID_LEN: usize = 64;
