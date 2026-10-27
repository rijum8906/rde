//! # Atomic File Operations
//!
//! Provides atomic file writes using the write-sync-rename pattern to prevent
//! readers from observing partially-written or truncated files.

use std::{
    fs::OpenOptions,
    io::{self, Write},
    path::Path,
};

/// Writes bytes to a file atomically by writing to a temporary file,
/// syncing file data and metadata to disk, and renaming it over the destination.
///
/// # Parameters
/// - `path`: destination file path
/// - `bytes`: file content to write
///
/// # Errors
/// Returns an [`std::io::Error`] if the parent directory cannot be created,
/// the temporary file cannot be opened/written/synced, or the rename fails.
pub fn write_atomic(path: &Path, bytes: &[u8]) -> io::Result<()> {
    // Step 1: Ensure the parent directory exists.
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Step 2: Compute temporary file path with PID and process uniqueness.
    let extension = match path.extension() {
        Some(ext) => format!("{}.{}.tmp", ext.to_string_lossy(), std::process::id()),
        None => format!("{}.tmp", std::process::id()),
    };
    let tmp_path = path.with_extension(extension);

    // Step 3: Write payload to the temporary file and sync to disk.
    {
        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&tmp_path)?;

        file.write_all(bytes)?;
        file.sync_all()?;
    }

    // Step 4: Atomically rename temporary file over target path.
    if let Err(err) = std::fs::rename(&tmp_path, path) {
        let _ = std::fs::remove_file(&tmp_path);
        return Err(err);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_write_atomic_success() {
        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("subdir").join("test.txt");

        write_atomic(&target, b"hello atomic world").unwrap();
        assert_eq!(std::fs::read(&target).unwrap(), b"hello atomic world");
    }

    #[test]
    fn test_write_atomic_overwrites_existing() {
        let dir = tempfile::tempdir().unwrap();
        let target = dir.path().join("test.txt");

        write_atomic(&target, b"first").unwrap();
        assert_eq!(std::fs::read(&target).unwrap(), b"first");

        write_atomic(&target, b"second").unwrap();
        assert_eq!(std::fs::read(&target).unwrap(), b"second");
    }
}
