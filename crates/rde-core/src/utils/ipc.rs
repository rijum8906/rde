use std::{
    env, fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
};

use crate::errors::RdeResult;

/// Get the XDG_RUNTIME_DIR and create the socket directory
///
/// Returns the path to the socket file that should be used.
///
/// # SECURITY:
/// - Directory is created with 0o700 (user-only access)
/// - Stale socket is cleaned up before new creation
/// - Falls back to /tmp only as last resort with warning
///
/// # NOTE:
/// - Does NOT create the socket itself (that's done with bind())
/// - Only ensures the directory exists and is ready
/// - If socket exists, it's removed (stale cleanup)
///
/// # XDG Specification
/// See: https://specifications.freedesktop.org/basedir/latest/
pub fn get_socket_path() -> RdeResult<PathBuf> {
    // 1. Get XDG_RUNTIME_DIR
    let xdg_runtime_dir = get_xdg_runtime_dir()?;

    // 2. Build application directory path
    let app_runtime_dir = xdg_runtime_dir.join("rde");

    // 3. Ensure directory exists with correct permissions
    ensure_directory(&app_runtime_dir)?;

    // 4. Build socket path
    let socket_path = app_runtime_dir.join("rde.sock");

    // 5. Remove stale socket if it exists
    if socket_path.exists() {
        fs::remove_file(&socket_path)?;
    }

    Ok(socket_path)
}

/// Get the XDG_RUNTIME_DIR path with proper fallback
fn get_xdg_runtime_dir() -> RdeResult<PathBuf> {
    // Try environment variable first
    if let Ok(runtime_dir) = env::var("XDG_RUNTIME_DIR")
        && !runtime_dir.is_empty()
    {
        let path = PathBuf::from(runtime_dir);
        if path.is_absolute() {
            return Ok(path);
        }
    }

    // Fallback: Use /run/user/<UID>/
    let uid = unsafe { libc::getuid() };
    let fallback_path = PathBuf::from(format!("/run/user/{}", uid));

    if fallback_path.exists() {
        return Ok(fallback_path);
    }

    // Last resort: /tmp (with warning)
    eprintln!(
        "⚠️  XDG_RUNTIME_DIR not set and /run/user/{} not found!",
        uid
    );
    eprintln!("⚠️  Falling back to /tmp (insecure!)");
    Ok(PathBuf::from("/tmp"))
}

/// Ensure directory exists with correct permissions
fn ensure_directory(path: &Path) -> RdeResult<()> {
    if !path.exists() {
        // Create directory
        fs::create_dir_all(path)?;

        // Set permissions to 0o700 (user-only)
        let perms = fs::Permissions::from_mode(0o700);
        fs::set_permissions(path, perms)?;
    }

    // Verify permissions
    let metadata = fs::metadata(path)?;
    let perms = metadata.permissions();
    let mode = perms.mode();

    // Only check if it's not 0o700
    if mode & 0o777 != 0o700 {
        eprintln!(
            "⚠️  Directory {} has wrong permissions: {:o}",
            path.display(),
            mode
        );
        eprintln!("⚠️  Fixing to 0o700...");
        let perms = fs::Permissions::from_mode(0o700);
        fs::set_permissions(path, perms)?;
    }

    Ok(())
}

/// Clean up the socket file
pub fn cleanup_socket(socket_path: &Path) -> RdeResult<()> {
    if socket_path.exists() {
        fs::remove_file(socket_path)?;
        println!("🧹 Cleaned up socket: {}", socket_path.display());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_socket_path_creation() {
        let temp_dir = tempdir().unwrap();
        let path = temp_dir.path().join("rde").join("test.sock");

        // Directory doesn't exist yet
        assert!(!path.parent().unwrap().exists());

        // Create directory
        ensure_directory(path.parent().unwrap()).unwrap();

        // Directory should exist with correct permissions
        assert!(path.parent().unwrap().exists());
        let meta = fs::metadata(path.parent().unwrap()).unwrap();
        let perms = meta.permissions();
        assert_eq!(perms.mode() & 0o777, 0o700);
    }

    #[test]
    fn test_stale_socket_removal() {
        let temp_dir = tempdir().unwrap();
        let socket_path = temp_dir.path().join("test.sock");

        // Create a dummy file
        fs::write(&socket_path, "stale").unwrap();
        assert!(socket_path.exists());

        // Remove it
        if socket_path.exists() {
            fs::remove_file(&socket_path).unwrap();
        }
        assert!(!socket_path.exists());
    }
}
