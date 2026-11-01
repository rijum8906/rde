//! # RDE Brightness Service
//!
//! Brightness control service for the Riju Desktop Environment, split into
//! domain, application, and infrastructure layers.
//!
//! # Layers
//! - [`domain`]: display detection and hardware actuation, free of D-Bus and async runtimes.
//! - [`application`]: command routing and the in-memory brightness state.
//! - [`infrastructure`]: the `org.rde.Brightness` D-Bus object and `rde-daemon` supervision.

pub mod application;
pub mod domain;
pub mod infrastructure;

use std::time::Duration;

/// Service name reported to the `rde-daemon` supervisor.
pub const SERVICE_NAME: &str = "brightness";

/// Package version advertised over D-Bus and during registration.
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Capabilities advertised during the registration handshake.
pub const CAPABILITIES: &[&str] = &["backlight"];

/// Well-known D-Bus name owned by this service on the session bus.
pub const DBUS_SERVICE_NAME: &str = "org.rde.Brightness";

/// Object path exposing `org.rde.Brightness` on the session bus.
pub const DBUS_OBJECT_PATH: &str = "/org/rde/Brightness";

/// Maximum number of attempts made when connecting to the supervision socket.
pub const MAX_SOCKET_CONN_RETRY_COUNT: u32 = 5;

/// Delay between supervision socket connection attempts, in milliseconds.
pub const SOCKET_CONN_RETRY_DELAY_MS: u64 = 2_000;

/// Maximum time spent waiting for the supervision task to stop on shutdown.
pub const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(2);
