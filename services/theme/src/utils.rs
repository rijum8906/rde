use std::path::PathBuf;

use zbus::fdo::Error;
use zbus::fdo::Result;

use crate::theme::Theme;

pub fn theme_name_from_key(key: &str) -> Option<String> {
    let parts: Vec<&str> = key.split(':').collect();
    if parts.len() == 2 {
        Some(parts[0].to_string())
    } else {
        None
    }
}

pub fn theme_name(theme: &Theme) -> String {
    format!("{}:{}", &theme.name, &theme.mode.to_string())
}

/// Creates a new RDE storage directory under the user's local data directory.
/// This is idempotent - if the directory already exists, it will not be modified.
pub fn create_new_rde_storage(storage_name: &str) -> Result<PathBuf> {
    let data_dir = match dirs::data_dir() {
        Some(dir) => dir,
        None => {
            return Err(Error::Failed(
                "failed to find local data directory".to_string(),
            ));
        }
    };

    let storage_dir = data_dir.join("rde").join(storage_name);
    if !storage_dir.exists() {
        std::fs::create_dir_all(&storage_dir).map_err(|e| Error::Failed(e.to_string()))?;
    }
    Ok(storage_dir)
}
