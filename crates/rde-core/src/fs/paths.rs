//! # XDG Base Directory Helpers
//!
//! Layer: fs.
//! Called by: `app`, `adapter`, and `adapter::detect`, which all need a base
//! directory before they can locate their own files.
//! Calls: `std::env` only.
//!
//! Resolves the three XDG base directories the service uses, each falling back
//! to the conventional home-relative location when the variable is unset or
//! empty.

use std::{env, path::PathBuf};

/// Resolves `$XDG_DATA_HOME`, falling back to `~/.local/share`.
#[must_use]
pub fn xdg_data_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_DATA_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".local").join("share")
}

/// Resolves `$XDG_CONFIG_HOME`, falling back to `~/.config`.
#[must_use]
pub fn xdg_config_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_CONFIG_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".config")
}

/// Resolves `$XDG_CACHE_HOME`, falling back to `~/.cache`.
#[must_use]
pub fn xdg_cache_home() -> PathBuf {
    if let Ok(path) = env::var("XDG_CACHE_HOME") {
        if !path.is_empty() {
            return PathBuf::from(path);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".cache")
}
