//! # Inter-Process Communication (IPC) Module
//!
//! Handles Unix domain socket communication between `rde-wifi` service and `rde-daemon` supervisor.
//! Provides health check responses, status updates, registration handshakes, and graceful shutdowns.
//!
//! ## Features
//! - Daemon request and response message handlers
//! - Asynchronous IPC socket loop runner
//!
//! ## Related
//! - [`crate::ipc::handler`]
//! - [`crate::ipc::daemon_request`]
//! - [`crate::ipc::daemon_response`]
//! - [`rde_ipc`](../../crates/rde-ipc)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod daemon_request;
pub mod daemon_response;
pub mod handler;
