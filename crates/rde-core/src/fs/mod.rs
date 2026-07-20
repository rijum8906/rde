use std::{env::home_dir, path::PathBuf};

use crate::errors::{RdeError, RdeResult};

/// Returns the home dir with RdeError
fn get_home_dir() -> RdeResult<PathBuf> {
    let home_dir = home_dir()
        .ok_or("Failed to get home directory")
        .map_err(|e| RdeError::NotFound(e.to_string()))?;

    Ok(home_dir)
}

/// Returns the path to the rde global cache directory
/// i.e., ~/.cache/rde/
pub fn rde_cache_dir() -> RdeResult<PathBuf> {
    // get the home directory
    let home = get_home_dir()?;

    let rde_cache_dir = home.join(".cache").join("rde");
    // create the rde cache directory if it doesn't exist
    std::fs::create_dir_all(&rde_cache_dir).map_err(|e| RdeError::NotFound(e.to_string()))?;

    Ok(rde_cache_dir)
}

/// Returns the path to the rde service cache directory
/// i.e., ~/.cache/rde/{service_name}/
pub fn rde_service_cache_dir(service_name: &str) -> RdeResult<PathBuf> {
    let rde_cache_dir = rde_cache_dir()?;

    let service_cache_dir = rde_cache_dir.join(service_name);
    // create the service cache directory if it doesn't exist
    std::fs::create_dir(&service_cache_dir).map_err(|e| RdeError::NotFound(e.to_string()))?;

    Ok(service_cache_dir)
}

/// Returns the path to the rde logs directory
/// i.e., ~/.local/rde/logs
pub fn rde_logs_dir() -> RdeResult<PathBuf> {
    let home = get_home_dir()?;

    let rde_logs_dir = home.join(".local").join("rde").join("logs");
    // create the rde logs directory if it doesn't exist
    std::fs::create_dir_all(&rde_logs_dir).map_err(|e| RdeError::NotFound(e.to_string()))?;

    Ok(rde_logs_dir)
}

/// Returns the path to the rde service logs directory
/// i.e., ~/.local/rde/logs/{service_name}/
pub fn rde_service_logs_dir(service_name: &str) -> RdeResult<PathBuf> {
    let rde_logs_dir = rde_logs_dir()?;

    let service_logs_dir = rde_logs_dir.join(service_name);
    // create the service logs directory if it doesn't exist
    std::fs::create_dir(&service_logs_dir).map_err(|e| RdeError::NotFound(e.to_string()))?;

    Ok(service_logs_dir)
}
