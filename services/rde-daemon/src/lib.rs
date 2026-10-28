//! # RDE Daemon Library (`rde-daemon`)
//!
//! `rde-daemon` is the supervision service of the Riju Desktop Environment
//! (RDE). It owns the internal Unix socket that every other service connects
//! to, keeps a registry of the running services, and shuts down cleanly when
//! the session ends. It exposes no user-facing D-Bus API; each service owns
//! its own interface.
//!
//! ## Features
//! - Supervision socket bound at `$XDG_RUNTIME_DIR/rde/rde.sock` (mode `0600`)
//! - Service registry with registration, deregistration, and status tracking
//! - Protocol version validation for every connecting service
//! - Per-connection isolation with automatic registry cleanup on disconnect
//! - Graceful shutdown that stops accepting and removes the socket file
//!
//! ## Architecture
//! - **app**: global daemon state and the service registry
//! - **handler**: request and response processing for connected services
//! - **ipc**: supervision server that owns the listening socket
//!
//! ## Related
//! - [`rde_ipc`](../../crates/rde-ipc): socket primitives and message types
//! - [`rde_core`](../../crates/rde-core): errors, logging, and path helpers
//! - [IPC Protocol Design](../../docs/ipc-protocol.md)
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod app;
pub mod backend;
pub mod handler;
pub mod ipc;
