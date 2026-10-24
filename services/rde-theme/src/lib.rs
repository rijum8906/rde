//! # RDE Theme Manager Library (`rde-theme`)
//!
//! Centralizes visual appearance for the RDE desktop: a persisted theme database,
//! generated Material 3 palettes, and toolkit output published as `org.rde.Theme`.

pub mod app;
pub mod backend;
pub mod constants;
pub mod dbus;
pub mod domain;
mod file_utils;
pub mod handler;
pub mod paths;
pub mod theme_store;
