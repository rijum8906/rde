//! # Service Constants
//!
//! Compile-time configuration shared by the volume service lifecycle, the
//! D-Bus interface, and the daemon supervision task.
//!
//! ## Constants
//! - [`SERVICE_NAME`][]: name registered with the daemon supervisor
//! - [`MAX_SOCKET_CONN_RETRY_COUNT`] / [`SOCKET_CONN_RETRY_DELAY_MS`][]: socket retry policy
//! - [`SHUTDOWN_TIMEOUT`][]: upper bound when waiting for supervision teardown
//!
//! The public D-Bus identifiers stay in [`crate::domain::models`] and are
//! re-exported here so the lifecycle code has a single import site.
//!
//! ## Related
//! - [`crate::app`][]: consumes the retry and shutdown policy
//! - [`crate::domain::models`][]: volume limits and D-Bus identifiers
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::time::Duration;

pub use crate::domain::models::{DBUS_OBJECT_PATH, DBUS_SERVICE_NAME};

/// Service name reported to the `rde-daemon` supervisor.
pub const SERVICE_NAME: &str = "volume";

/// Capabilities advertised during the registration handshake.
pub const CAPABILITIES: &[&str] = &["alsa", "mute"];

/// Maximum number of attempts made when connecting to the supervision socket.
pub const MAX_SOCKET_CONN_RETRY_COUNT: u32 = 5;

/// Delay between supervision socket connection attempts, in milliseconds.
pub const SOCKET_CONN_RETRY_DELAY_MS: u64 = 2_000;

/// Maximum time spent waiting for the supervision task to stop on shutdown.
pub const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(2);
