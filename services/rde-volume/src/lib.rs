//! # RDE Volume Service Library (`rde-volume`)
//!
//! `rde-volume` is an independent, decoupled microservice within the Riju Desktop Environment (RDE).
//! It provides high-level master audio volume and mute management by interfacing directly with
//! Linux's ALSA sound subsystem.
//!
//! ## Features
//! - Master volume and mute state querying and mutations
//! - Public session D-Bus interface (`org.rde.Volume`) at `/org/rde/Volume`
//! - Reactive signals for volume and mute state transitions
//! - Unix socket IPC connection for daemon supervision
//! - Pluggable audio controller abstraction supporting ALSA and test mocks
//!
//! ## Related
//! - [`rde-daemon`](../rde-daemon)
//! - [`rde-ipc`](../../crates/rde-ipc)
//! - [`rde-core`](../../crates/rde-core)
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
pub mod dbus;
pub mod domain;
pub mod infra;
pub mod ipc;
