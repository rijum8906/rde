//! # Service Constants
//!
//! Service constants for names, paths, schema versions, and D-Bus interfaces.

use std::time::Duration;

/// Service name reported to the supervisor.
pub const SERVICE_NAME: &str = "theme";

/// Capabilities advertised to supervision.
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

/// Default fallback source color used when dynamic wallpaper extraction is unavailable.
pub const DEFAULT_FALLBACK_COLOR: &str = crate::domain::resolved::FALLBACK_SEED_COLOR;
