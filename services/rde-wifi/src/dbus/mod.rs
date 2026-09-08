//! # Session D-Bus Interface Module
//!
//! Exposes the high-level `org.rde.wifi` session bus D-Bus service for user interfaces,
//! desktop control panels, and status bar indicators.
//!
//! ## Features
//! - Public `org.rde.wifi` D-Bus interface definition
//! - D-Bus method, property, and signal bindings
//!
//! ## Related
//! - [`crate::dbus::iface::WifiInterface`]
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
