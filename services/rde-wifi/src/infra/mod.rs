//! # Infrastructure Layer Module
//!
//! Provides low-level system integration drivers, system D-Bus proxy interfaces,
//! and mock interfaces for unit testing.
//!
//! ## Features
//! - Low-level `zbus` D-Bus proxy bindings for NetworkManager
//! - Conditional export of mock proxy objects during test builds
//!
//! ## Related
//! - [`crate::infra::dbus::nm_proxy`]
//! - [`crate::infra::dbus::mock`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod dbus;
