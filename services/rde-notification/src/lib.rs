//! # RDE Notification Service Library (`rde-notification`)
//!
//! `rde-notification` is a decoupled microservice within the Riju Desktop
//! Environment (RDE) that will own desktop notification delivery.
//!
//! ## Features
//! - Application singleton ([`app::App`]) with structured logging
//! - Unix socket supervision task for `rde-daemon` (health checks, status, shutdown)
//! - Graceful teardown on `SIGINT`, `SIGTERM`, or a supervisor request
//!
//! ## Status
//! The service lifecycle and supervision layers are implemented. The D-Bus
//! surface (`org.rde.Notification`) and the notification queue backend are
//! still placeholders, so no notification API is exposed yet.
//!
//! ## Architecture
//! - **app**: Application singleton, event loop, and supervision task
//! - **handler**: Routing and handling of supervisor requests and responses
//! - **constants**: Service name and retry policy
//! - **dbus**: Reserved D-Bus interface module
//! - **backend**: Reserved notification backend module
//!
//! ## Related
//! - [`rde-daemon`](../rde-daemon)
//! - [`rde-ipc`](../../crates/rde-ipc)
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
pub mod handler;
