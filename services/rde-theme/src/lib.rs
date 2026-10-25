//! # RDE Theme Manager Library (`rde-theme`)
//!
//! Centralizes visual appearance for the RDE desktop: author-owned theme manifests,
//! a machine-owned factual registry, user-owned settings, generated Material 3
//! palettes, toolkit adapters, and D-Bus publication under `org.rde.Theme`.

pub mod app;
pub mod backend;
pub mod constants;
pub mod dbus;
pub mod domain;
pub mod fs;
pub mod handler;
pub mod paths;
pub mod service;
pub mod theme_store;
