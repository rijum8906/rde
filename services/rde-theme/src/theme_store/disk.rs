//! # Theme Database Disk Operations
//!
//! Low-level, atomic file access for the theme database. The store keeps the
//! in-memory view consistent with these files; this module only knows how to
//! read, write, scan, and remove them.
//!
//! ## Features
//! - Atomic writes through a temporary file plus `rename`, so a crash never
//!   leaves a half-written `themes.toml` or manifest behind
//! - Corrupt files are quarantined instead of silently discarded
//! - Manifest scanning tolerates broken entries and reports them as warnings
//! - Schema-version warnings for files written by a newer service version
//!
//! ## Related
//! - [`crate::paths::ThemePaths`][]: path derivation
//! - [`crate::theme_store::ThemeStore`][]: owner of the in-memory state
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
};

use rde_core::errors::{RdeError, RdeResult};
use serde::de::DeserializeOwned;
use tracing::{info, warn};

use crate::{
    constants::{MANIFEST_FILE_NAME, MANIFEST_SCHEMA_VERSION, REGISTRY_SCHEMA_VERSION},
    domain::{
        theme::{ThemeId, ThemeManifest},
        theme_config_file::ThemeRegistryFile,
    },
    paths::ThemePaths,
};

/// Reads the theme registry, returning `None` when the file is absent.
///
/// # Errors
/// Returns [`RdeError::Io`] when the file exists but cannot be read and
/// [`RdeError::InvalidConfig`] when it cannot be parsed.
pub(super) fn read_registry(path: &Path) -> RdeResult<Option<ThemeRegistryFile>> {
    let registry = read_toml::<ThemeRegistryFile>(path)?;

    if let Some(registry) = &registry
        && registry.schema_version > REGISTRY_SCHEMA_VERSION
    {
        warn!(
            schema_version = registry.schema_version,
            supported = REGISTRY_SCHEMA_VERSION,
            path = %path.display(),
            "theme registry was written by a newer service version"
        );
    }

    Ok(registry)
}

/// Writes the theme registry atomically.
///
/// # Errors
/// Returns [`RdeError::Io`] when the file or its parent directory cannot be
/// written.
pub(super) fn write_registry(path: &Path, registry: &ThemeRegistryFile) -> RdeResult<()> {
    let encoded = toml::to_string_pretty(registry).map_err(|error| {
        RdeError::InvalidConfig(format!("theme registry could not be encoded: {error}"))
    })?;

    write_atomic(path, &encoded)
}

/// Reads a single theme manifest.
///
/// # Errors
/// Returns [`RdeError::NotFound`] when the manifest is missing,
/// [`RdeError::Io`] when it cannot be read, and [`RdeError::InvalidConfig`]
/// when it cannot be parsed.
pub(super) fn read_manifest(path: &Path) -> RdeResult<ThemeManifest> {
    let manifest = read_toml::<ThemeManifest>(path)?.ok_or_else(|| {
        RdeError::NotFound(format!("theme manifest {} is missing", path.display()))
    })?;

    if manifest.schema_version > MANIFEST_SCHEMA_VERSION {
        warn!(
            schema_version = manifest.schema_version,
            supported = MANIFEST_SCHEMA_VERSION,
            path = %path.display(),
            "theme manifest was written by a newer service version"
        );
    }

    Ok(manifest)
}

/// Writes a theme manifest atomically, creating the theme directory.
///
/// # Errors
/// Returns [`RdeError::Io`] when the directory or file cannot be written.
pub(super) fn write_manifest(path: &Path, manifest: &ThemeManifest) -> RdeResult<()> {
    let encoded = toml::to_string_pretty(manifest).map_err(|error| {
        RdeError::InvalidConfig(format!("theme manifest could not be encoded: {error}"))
    })?;

    write_atomic(path, &encoded)
}

/// Scans the `themes/` directory and loads every valid manifest.
///
/// Invalid directories are skipped with a warning so one broken theme cannot
/// prevent the service from starting or hide the remaining themes.
///
/// # Returns
/// A map from theme identifier to manifest, ordered by identifier.
///
/// # Errors
/// Returns [`RdeError::Io`] when the themes directory itself cannot be read.
pub(super) fn scan_manifests(themes_dir: &Path) -> RdeResult<BTreeMap<ThemeId, ThemeManifest>> {
    let entries = fs::read_dir(themes_dir).map_err(RdeError::Io)?;
    let mut manifests = BTreeMap::new();

    for entry in entries {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                warn!(%error, "skipping unreadable theme directory entry");
                continue;
            }
        };

        // Step 1: Only directories can hold a theme.
        match entry.file_type() {
            Ok(file_type) if file_type.is_dir() => {}
            Ok(_) => continue,
            Err(error) => {
                warn!(path = %entry.path().display(), %error, "skipping theme entry with unknown type");
                continue;
            }
        }

        // Step 2: The directory name must be a valid theme identifier.
        let directory_name = entry.file_name();
        let Some(directory_name) = directory_name.to_str() else {
            warn!(path = %entry.path().display(), "skipping theme directory with a non-UTF-8 name");
            continue;
        };
        let theme = match ThemeId::new(directory_name) {
            Ok(theme) => theme,
            Err(error) => {
                warn!(path = %entry.path().display(), %error, "skipping theme directory with an invalid name");
                continue;
            }
        };

        // Step 3: Load and validate the manifest.
        let manifest_path = entry.path().join(MANIFEST_FILE_NAME);
        let manifest = match read_manifest(&manifest_path) {
            Ok(manifest) => manifest,
            Err(error) => {
                warn!(path = %manifest_path.display(), %error, "skipping theme with an unreadable manifest");
                continue;
            }
        };

        if manifest.name != theme {
            warn!(
                directory = %theme,
                manifest = %manifest.name,
                "skipping theme whose manifest name does not match its directory"
            );
            continue;
        }

        info!(theme = %theme, "loaded theme manifest");
        manifests.insert(theme, manifest);
    }

    Ok(manifests)
}

/// Removes an installed theme's directory and its manifest.
///
/// # Errors
/// Returns [`RdeError::Io`] when the directory cannot be removed.
pub(super) fn remove_theme_dir(paths: &ThemePaths, theme: &ThemeId) -> RdeResult<()> {
    let directory = paths.theme_dir(theme);

    match fs::remove_dir_all(&directory) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(RdeError::Io(error)),
    }
}

/// Moves an unparsable file aside so the service can rebuild it.
///
/// # Returns
/// The path the file was moved to, ending in `.invalid`.
///
/// # Errors
/// Returns [`RdeError::Io`] when the file cannot be renamed.
pub(super) fn quarantine(path: &Path) -> RdeResult<PathBuf> {
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| RdeError::InvalidConfig(format!("invalid path {}", path.display())))?;
    let destination = path.with_file_name(format!("{file_name}.invalid"));

    fs::rename(path, &destination).map_err(RdeError::Io)?;

    Ok(destination)
}

/// Reads and parses a TOML document, returning `None` when it does not exist.
///
/// # Errors
/// Returns [`RdeError::Io`] for read failures and [`RdeError::InvalidConfig`]
/// when the document cannot be parsed.
fn read_toml<T: DeserializeOwned>(path: &Path) -> RdeResult<Option<T>> {
    let contents = match fs::read_to_string(path) {
        Ok(contents) => contents,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(RdeError::Io(error)),
    };

    toml::from_str(&contents).map(Some).map_err(|error| {
        RdeError::InvalidConfig(format!("failed to parse {}: {error}", path.display()))
    })
}

/// Writes a file atomically by renaming a fully written temporary file.
///
/// # Errors
/// Returns [`RdeError::InvalidConfig`] when the path has no file name and
/// [`RdeError::Io`] when the parent directory cannot be created or the file
/// cannot be written or renamed.
fn write_atomic(path: &Path, contents: &str) -> RdeResult<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(RdeError::Io)?;
    }

    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| RdeError::InvalidConfig(format!("invalid path {}", path.display())))?;
    let temporary = path.with_file_name(format!("{file_name}.tmp"));

    // Step 1: Write the complete document to a sibling temporary file.
    fs::write(&temporary, contents).map_err(RdeError::Io)?;

    // Step 2: Atomically replace the destination; clean up on failure so a
    // read-only filesystem does not accumulate stale temporary files.
    if let Err(error) = fs::rename(&temporary, path) {
        let _ = fs::remove_file(&temporary);
        return Err(RdeError::Io(error));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(label: &str) -> PathBuf {
        let process = std::process::id();
        let path = std::env::temp_dir().join(format!("rde-theme-disk-{process}-{label}"));
        let _ = fs::remove_dir_all(&path);
        fs::create_dir_all(&path).expect("create temporary directory");
        path
    }

    #[test]
    fn missing_registry_reads_as_none() {
        let path = temp_dir("missing").join("themes.toml");
        assert!(
            read_registry(&path)
                .expect("missing file is not an error")
                .is_none()
        );
    }

    #[test]
    fn corrupt_registry_is_reported_and_quarantinable() {
        let path = temp_dir("corrupt").join("themes.toml");
        fs::write(&path, "this is not toml = [").expect("write corrupt registry");

        assert!(read_registry(&path).is_err());

        let quarantined = quarantine(&path).expect("quarantine corrupt registry");
        assert!(quarantined.ends_with("themes.toml.invalid"));
        assert!(!path.exists(), "the corrupt registry must be moved aside");
    }

    #[test]
    fn manifest_round_trips_atomically() {
        let path = temp_dir("manifest").join("default").join("theme.toml");
        let manifest = ThemeManifest::default_theme().expect("default manifest");

        write_manifest(&path, &manifest).expect("write manifest");
        let loaded = read_manifest(&path).expect("read manifest");

        assert_eq!(loaded, manifest);
        assert!(
            !path.with_file_name("theme.toml.tmp").exists(),
            "temporary file must not survive a successful write"
        );
    }
}
