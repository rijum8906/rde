//! # Message Handlers
//!
//! Dispatch layer between the supervision socket and the daemon state. Requests
//! mutate the service registry; responses are recorded for diagnostics.
//!
//! ## Related
//! - [`crate::ipc::server`]: decodes frames and calls these handlers
//! - [`crate::app::App`]: shared state both handlers operate on
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod request;
pub mod response;
