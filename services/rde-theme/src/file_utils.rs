//! # Atomic File Helpers
//!
//! Small filesystem utilities shared by the theme database and the Qt
//! integration. Every configuration file the service owns is replaced
//! atomically, so a crash or a full disk cannot leave a truncated document that
//! a toolkit would fail to parse.
//!
//! ## Features
//! - Atomic replacement through a sibling temporary file and `rename`
//! - Conditional writes that skip unchanged content, avoiding needless
//!   modification times that would make Qt reload its configuration
//! - Temporary files are cleaned up when the rename fails
//!
//! ## Related
//! - [`crate::theme_store::disk`][]: theme database persistence
//! - [`crate::backend::qt`][]: generated Qt and KDE configuration files
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
    fs,
    path::{Path, PathBuf},
};

use rde_core::errors::{RdeError, RdeResult};

/// Writes a file atomically, creating its parent directory when needed.
///
/// # Parameters
/// - `path`: destination file
/// - `contents`: complete document to write
///
/// # Errors
/// Returns [`RdeError::InvalidConfig`] when the path has no usable file name
/// and [`RdeError::Io`] when the directory cannot be created or the file cannot
/// be written or renamed.
pub(crate) fn write_atomic(path: &Path, contents: &str) -> RdeResult<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(RdeError::Io)?;
    }

    let temporary = temporary_path(path)?;

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

/// Writes a file atomically unless it already contains exactly these bytes.
///
/// # Parameters
/// - `path`: destination file
/// - `contents`: complete document to write
///
/// # Returns
/// `true` when the file was written, `false` when it was already up to date.
///
/// # Errors
/// Returns the same errors as [`write_atomic`].
pub(crate) fn write_atomic_if_changed(path: &Path, contents: &str) -> RdeResult<bool> {
    // Step 1: Skip identical content so configuration watchers (qt5ct, qt6ct)
    // are not woken up for a no-op.
    if fs::read_to_string(path)
        .map(|existing| existing == contents)
        .unwrap_or(false)
    {
        return Ok(false);
    }

    // Step 2: Replace the file atomically.
    write_atomic(path, contents)?;
    Ok(true)
}

/// Builds the sibling temporary path used by [`write_atomic`].
///
/// # Errors
/// Returns [`RdeError::InvalidConfig`] when the path has no UTF-8 file name.
fn temporary_path(path: &Path) -> RdeResult<PathBuf> {
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| RdeError::InvalidConfig(format!("invalid path {}", path.display())))?;

    Ok(path.with_file_name(format!("{file_name}.tmp")))
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    fn temp_file(label: &str) -> PathBuf {
        let directory =
            std::env::temp_dir().join(format!("rde-theme-files-{}-{label}", std::process::id()));
        let _ = fs::remove_dir_all(&directory);

        directory.join("nested").join("file.conf")
    }

    #[test]
    fn creates_parent_directories_and_writes_content() {
        let path = temp_file("write");

        write_atomic(&path, "hello").expect("write file");

        assert_eq!(fs::read_to_string(&path).expect("read back"), "hello");
        assert!(!path.with_file_name("file.conf.tmp").exists());
        assert!(path.parent().expect("parent").exists());
    }

    #[test]
    fn unchanged_content_is_not_rewritten() {
        let path = temp_file("skip");
        write_atomic(&path, "stable").expect("initial write");
        let before = fs::metadata(&path)
            .expect("metadata")
            .modified()
            .expect("modification time");

        let written = write_atomic_if_changed(&path, "stable").expect("conditional write");

        assert!(!written, "identical content must not be rewritten");
        assert_eq!(
            fs::metadata(&path)
                .expect("metadata")
                .modified()
                .expect("modification time"),
            before
        );

        let written = write_atomic_if_changed(&path, "changed").expect("conditional write");
        assert!(written, "changed content must be written");
        assert_eq!(fs::read_to_string(&path).expect("read back"), "changed");
    }
}
