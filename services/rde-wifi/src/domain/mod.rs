//! # Domain Models Module
//!
//! Defines core domain models, access point data structures, security types,
//! and Wi-Fi state event enums shared across `rde-wifi`.
//!
//! ## Features
//! - High-level access point metadata models (`AccessPointInfo`)
//! - Wireless security enums (`SecurityType`)
//! - NetworkManager specific D-Bus flag mappings
//!
//! ## Related
//! - [`crate::domain::models`]
//! - [`crate::domain::nm_models`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

pub mod models;
pub mod nm_models;
