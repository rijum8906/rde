//! # Supervision Module
//!
//! Owns the internal Unix socket that services connect to. The daemon is the
//! only listener; every service is a client that connects on startup.
//!
//! ## Related
//! - [`rde_ipc::socket`]: listener and connection primitives
//! - [`crate::handler`]: message processing for accepted connections
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod server;
