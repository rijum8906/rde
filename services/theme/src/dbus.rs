use std::{collections::HashSet, fs, path::PathBuf};
use zbus::{
    fdo::{Error, Result},
    interface,
    object_server::SignalEmitter,
};

use crate::{
    constants::THEMES_LIST_FILE,
    defaults::DEFAULT_LIGHT_THEME,
    models::{ThemeFile, ThemeMode, ThemesList},
    theme::Theme,
    utils::{create_new_rde_storage, theme_name},
};

pub struct ThemeDBusService {
    pub theme_storage_path: PathBuf,
    mode: ThemeMode,
    current_theme: Theme,
    themes_list: ThemesList,

    // ===== Helper properties =====
    themes_list_path: PathBuf,
}

impl ThemeDBusService {
    pub fn new(storgae_name: String) -> Result<Self> {
        // Create the theme storage directory if not exists
        let theme_storage_path =
            create_new_rde_storage(&storgae_name).map_err(|e| Error::Failed(e.to_string()))?;

        // path of the themes list (where list of all available themes will be there)
        let themes_list_path = theme_storage_path.join(THEMES_LIST_FILE);

        // contains the themes list
        let themes_list: ThemesList;

        // If themes_list_path exists then retrieve the value and set to themes_list
        if themes_list_path.exists() {
            themes_list = serde_json::from_slice(
                &std::fs::read(&themes_list_path).map_err(|e| Error::Failed(e.to_string()))?,
            )
            .map_err(|e| Error::Failed(e.to_string()))?;
        } else {
            themes_list = ThemesList::default(); // Default themes list with
            let default_file_name_with_ext = DEFAULT_LIGHT_THEME.name.clone() + ".json";
            let default_theme_path = theme_storage_path.join(default_file_name_with_ext);
            // Create a default theme file
            let default_theme_file = ThemeFile::default_themes(); // Creates default light and dark theme
            // Parse the file to string
            let default_theme_file_str = serde_json::to_string(&default_theme_file)
                .map_err(|e| Error::Failed(e.to_string()))?;
            // Save this file
            fs::write(default_theme_path, default_theme_file_str)
                .map_err(|e| Error::Failed(e.to_string()))?;
            // Parse themes_list_file to string
            let themes_list_str =
                serde_json::to_string(&themes_list).map_err(|e| Error::Failed(e.to_string()))?;
            // Save the themes list to the storage
            fs::write(&themes_list_path, themes_list_str)
                .map_err(|e| Error::Failed(e.to_string()))?;
        }

        Ok(ThemeDBusService {
            theme_storage_path,
            mode: ThemeMode::Light,
            current_theme: DEFAULT_LIGHT_THEME.clone(),
            themes_list,
            themes_list_path,
        })
    }

    /// Returns the list of themes from the storage
    fn get_fresh_themes_list(&self) -> Result<ThemesList> {
        let themes_list_path = self.theme_storage_path.join(THEMES_LIST_FILE);

        // Get the themes list from the storage
        let themes_list: ThemesList = serde_json::from_slice(
            &std::fs::read(&themes_list_path).map_err(|e| Error::Failed(e.to_string()))?,
        )
        .map_err(|e| Error::Failed(e.to_string()))?;

        Ok(themes_list)
    }
}

impl ThemeDBusService {
    /// creates a theme file in the theme storage path
    /// if already exists, overwrites it
    fn create_theme_file(&self, file_name: String, theme_file: ThemeFile) -> Result<()> {
        let file_name_with_ext = file_name + ".json";
        let theme_file_str = match serde_json::to_string(&theme_file) {
            Ok(str) => str,
            // If the file cannot be serialized, return early without updating
            Err(e) => {
                return Err(Error::Failed(format!(
                    "couldn't parse theme file err: {}",
                    e
                )));
            }
        };

        // Create the new theme file
        let theme_file = self.theme_storage_path.join(&file_name_with_ext);
        match fs::write(theme_file, theme_file_str) {
            Ok(_) => Ok(()),
            Err(e) => Err(Error::Failed(e.to_string())),
        }
    }

    /// Updates the theme file for the given theme
    /// If the theme file already exists, it will be updated
    fn _update_theme_file(&self, theme: Theme) -> Result<()> {
        // Get the theme file path
        let file_name = theme.name.clone() + ".json";

        // Serialize the theme to JSON
        let theme_file_str = match serde_json::to_string(&theme) {
            Ok(str) => str,
            // If the file cannot be serialized, return early without updating
            Err(e) => {
                return Err(Error::Failed(format!(
                    "couldn't parse theme file err: {}",
                    e
                )));
            }
        };

        // Convert the json string to a ThemeFile
        let mut theme_file: ThemeFile = match serde_json::from_str(&theme_file_str) {
            Ok(file) => file,
            // If the file cannot be parsed, return early without updating
            Err(e) => {
                return Err(Error::Failed(format!(
                    "couldn't parse theme file err: {}",
                    e
                )));
            }
        };

        // Update the theme file with the new theme
        match theme.mode {
            ThemeMode::Light => theme_file.light_theme = Some(theme),
            ThemeMode::Dark => theme_file.dark_theme = Some(theme),
        }

        // Write the theme file to disk
        self.create_theme_file(file_name, theme_file)
    }

    /// Returns the theme file for the given theme name
    /// If the theme file does not exist, returns a default theme file
    fn get_theme_file(&self, theme_name: &str) -> Result<ThemeFile> {
        let theme_file_path = self.theme_storage_path.join(theme_name);

        // Read the existing theme file
        let existing_theme_file_raw = match std::fs::read(&theme_file_path) {
            Ok(raw) => raw,
            Err(_) => return Ok(ThemeFile::default()),
        };

        let theme_file: ThemeFile = serde_json::from_slice(&existing_theme_file_raw)
            .map_err(|e| Error::Failed(e.to_string()))?;

        Ok(theme_file)
    }

    /// Returns the current theme file for the given theme
    /// If the theme file does not exist, returns a default theme file
    fn get_current_theme_file(&self) -> Result<ThemeFile> {
        let file_name = self.current_theme.name.clone() + ".json";
        self.get_theme_file(&file_name)
    }

    // Saves the updated themes_list file in the disk
    fn save_themes_list(&self) -> Result<()> {
        let file_content =
            serde_json::to_string(&self.themes_list).map_err(|e| Error::Failed(e.to_string()))?;

        fs::write(&self.themes_list_path, file_content)
            .map_err(|e| Error::Failed(e.to_string()))?;
        Ok(())
    }
}

#[interface(name = "org.rde.Theme")]
impl ThemeDBusService {
    // ===== PROPERTIES =====

    #[zbus(property)]
    fn mode(&self) -> Result<String> {
        Ok(self.mode.to_string())
    }

    #[zbus(property)]
    async fn set_mode(
        &mut self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        mode: String,
    ) -> Result<()> {
        // Update mode
        let req_mode = ThemeMode::from_str(&mode)?;

        let theme_file = self.get_current_theme_file()?;

        match req_mode {
            ThemeMode::Light => {
                if let Some(theme) = theme_file.light_theme {
                    self.current_theme = theme;
                } else {
                    return Err(Error::InvalidArgs(
                        "light mode not available for current theme".to_string(),
                    ));
                }
            }
            ThemeMode::Dark => {
                if let Some(theme) = theme_file.dark_theme {
                    self.current_theme = theme;
                } else {
                    return Err(Error::InvalidArgs(
                        "dark mode not available for current theme".to_string(),
                    ));
                }
            }
        };

        // Update mode
        self.mode = req_mode;

        // Send signal
        self.mode_changed(&ctxt).await?;

        Ok(())
    }

    #[zbus(property)]
    pub fn current_theme(&self) -> Result<Theme> {
        Ok(self.current_theme.clone())
    }

    #[zbus(property)]
    async fn set_current_theme(
        &mut self,
        #[zbus(signal_context)] ctxt: SignalEmitter<'_>,
        theme: String,
    ) -> Result<()> {
        // Format the theme name with the current mode
        let theme_key = format!("{}:{}", theme, self.mode.to_string());
        let theme_name = theme.clone() + ".json";

        // Check if the theme is valid
        if !self.themes_list.themes.contains(&theme_key) {
            return Err(Error::InvalidArgs(
                "theme not found in themes list".to_string(),
            ));
        }

        // Get the theme from the themes list
        let current_theme_file = self.get_theme_file(&theme_name)?;

        // Update the current theme according to the last theme mode
        match self.mode {
            ThemeMode::Light => match current_theme_file.light_theme {
                Some(theme) => self.current_theme = theme,
                None => {
                    return Err(Error::InvalidArgs("light theme not found".to_string()));
                }
            },
            ThemeMode::Dark => match current_theme_file.dark_theme {
                Some(theme) => self.current_theme = theme,
                None => {
                    return Err(Error::InvalidArgs("dark theme not found".to_string()));
                }
            },
        }
        self.current_theme_changed(&ctxt).await?;
        Ok(())
    }

    // ===== METHODS =====

    async fn create_theme(&mut self, theme: Theme) -> Result<()> {
        let theme_key = theme_name(&theme);
        let file_name = theme.name.clone();
        // Check if the theme already exists
        if self.themes_list.themes.contains(&theme_key) {
            return Err(Error::InvalidArgs("theme already exists".to_string()));
        }

        // Create the theme file
        let mut theme_file = ThemeFile::default();
        match theme.mode {
            ThemeMode::Light => {
                theme_file.light_theme = Some(theme);
            }
            ThemeMode::Dark => {
                theme_file.dark_theme = Some(theme);
            }
        };
        self.create_theme_file(file_name, theme_file)?;

        // Updated and save themes list to the storage
        self.themes_list.themes.insert(theme_key);
        self.save_themes_list()?;

        // Return success
        Ok(())
    }

    async fn set_accent(&self, _accent_color: String) -> Result<()> {
        // Implementation to set accent color
        Err(Error::Failed("Not implemented".to_string()))
    }

    async fn list_themes(&self) -> Result<HashSet<String>> {
        // Get the themes list from the storage
        let themes_list: ThemesList = serde_json::from_slice(
            &std::fs::read(&self.themes_list_path).map_err(|e| Error::Failed(e.to_string()))?,
        )
        .map_err(|e| Error::Failed(e.to_string()))?;

        // Return the themes list
        Ok(themes_list.themes)
    }

    async fn refresh_themes_list(&mut self) -> Result<()> {
        let list = self.get_fresh_themes_list()?;
        self.themes_list = list;
        Ok(())
    }
}
