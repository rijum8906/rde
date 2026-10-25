//! # Filesystem Path Assurance
//!
//! Utilities to recursively verify and ensure directory and file existence
//! with detailed contextual errors.

use std::{
    fs::File,
    io,
    path::{Path, PathBuf},
};
use thiserror::Error;

/// Error encountered while ensuring filesystem paths.
#[derive(Debug, Error)]
pub enum EnsureError {
    /// Failed to create a directory.
    #[error("failed to create directory at '{path}': {source}")]
    CreateDir {
        path: PathBuf,
        #[source]
        source: io::Error,
    },

    /// Failed to touch or create a file.
    #[error("failed to ensure file at '{path}': {source}")]
    CreateFile {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
}

/// Recursively ensures that the specified directory exists.
///
/// # Parameters
/// - `path`: directory path to create if missing
///
/// # Errors
/// Returns [`EnsureError::CreateDir`] if creating the directory fails.
pub fn ensure_dir(path: &Path) -> Result<(), EnsureError> {
    if !path.exists() {
        std::fs::create_dir_all(path).map_err(|source| EnsureError::CreateDir {
            path: path.to_path_buf(),
            source,
        })?;
    }
    Ok(())
}

/// Ensures that a file exists, creating parent directories and an empty file if needed.
///
/// # Parameters
/// - `path`: file path to ensure
///
/// # Errors
/// Returns [`EnsureError::CreateDir`] if parent directory creation fails, or
/// [`EnsureError::CreateFile`] if file creation fails.
pub fn ensure_file(path: &Path) -> Result<(), EnsureError> {
    if let Some(parent) = path.parent() {
        ensure_dir(parent)?;
    }
    if !path.exists() {
        File::create(path).map_err(|source| EnsureError::CreateFile {
            path: path.to_path_buf(),
            source,
        })?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ensure_dir_and_file() {
        let dir = tempfile::tempdir().unwrap();
        let nested_dir = dir.path().join("a").join("b");
        ensure_dir(&nested_dir).unwrap();
        assert!(nested_dir.is_dir());

        let nested_file = nested_dir.join("c.txt");
        ensure_file(&nested_file).unwrap();
        assert!(nested_file.is_file());
    }
}
