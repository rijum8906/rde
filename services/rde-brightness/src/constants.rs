//! # Service Configuration Constants
//!
//! Defines compile-time and runtime configuration values for the brightness service.
//!
//! ## Constants
//! - `MAX_SOCKET_CONN_RETRY_COUNT`: Maximum connection retry attempts to daemon supervisor
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

/// Maximum number of retry attempts for connecting to the daemon supervisor via IPC socket.
///
/// Connection attempts are spaced 2 seconds apart (2000ms). With 5 retries, total timeout is ~10s.
pub const MAX_SOCKET_CONN_RETRY_COUNT: usize = 5;
