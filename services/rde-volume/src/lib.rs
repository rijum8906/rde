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
//! - Unix socket supervision task for `rde-daemon`
//! - Pluggable audio controller abstraction supporting ALSA and test mocks
//!
//! ## Architecture
//! - **app**: Application singleton ([`app::App`]), event loop, and supervision task
//! - **handler**: Routing and handling of supervisor requests and responses
//! - **constants**: Service name, D-Bus contract, and retry policy
//! - **backend**: Volume business logic and boundary handling
//! - **dbus**: D-Bus interface and signal definitions
//! - **domain**: Volume state model and limits
//! - **infra**: ALSA and mock audio controller implementations
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
pub mod constants;
pub mod dbus;
pub mod domain;
pub mod handler;
pub mod infra;
