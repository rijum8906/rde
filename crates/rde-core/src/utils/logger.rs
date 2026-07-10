use std::{env::home_dir, path::PathBuf};

use crate::{
    constants::rde::RDE_LOGS_DIR,
    errors::{RdeError, RdeResult},
};

/// Create the logger directory if it doesn't exist
pub fn init_log_dir() -> RdeResult<PathBuf> {
    if let Some(home_dir) = home_dir() {
        let rde_logs_dir = home_dir.join(RDE_LOGS_DIR);

        // create the directory if it doesn't exist
        if !rde_logs_dir.exists() {
            std::fs::create_dir_all(&rde_logs_dir).map_err(|e| RdeError::System(e.to_string()))?;
        }

        Ok(rde_logs_dir)
    } else {
        Err(RdeError::System("Home directory not found".to_string()))
    }
}
