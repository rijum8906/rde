//! # D-Bus Presentation Module (`rde-notification`)
//!
//! Reserved for the public notification interface.
//!
//! ## Status
//! No interface is implemented yet. The planned contract is a session-bus
//! service named `org.rde.Notification`, served at `/org/rde/Notification`,
//! mirroring the layout used by the other RDE services.
//!
//! ## Related
//! - [`crate::app::App`][]: will serve the interface during startup
//! - [`crate::backend`][]: will provide the notification queue
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod iface;
