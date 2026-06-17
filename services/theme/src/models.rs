use std::collections::HashSet;

use serde::{Deserialize, Serialize};
use zbus::{
    fdo::{Error, Result},
    zvariant::{OwnedValue, Type, Value},
};

use crate::{
    defaults::{DEFAULT_DARK_THEME, DEFAULT_LIGHT_THEME},
    theme::Theme,
};

#[derive(Debug, Type, Serialize, Deserialize, Clone, Value, PartialEq, OwnedValue, Default)]
pub enum ThemeMode {
    #[default]
    Light,
    Dark,
}

impl ThemeMode {
    pub fn from_str(mode: &str) -> Result<Self> {
        match mode.to_lowercase().as_str() {
            "light" => Ok(ThemeMode::Light),
            "dark" => Ok(ThemeMode::Dark),
            _ => Err(Error::Failed("Invalid mode".to_string())),
        }
    }

    pub fn to_string(&self) -> String {
        match self {
            ThemeMode::Light => "light".to_string(),
            ThemeMode::Dark => "dark".to_string(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct ThemeFile {
    pub light_theme: Option<Theme>,
    pub dark_theme: Option<Theme>,
}

impl ThemeFile {
    pub fn default_themes() -> Self {
        Self {
            light_theme: Some(DEFAULT_LIGHT_THEME.clone()),
            dark_theme: Some(DEFAULT_DARK_THEME.clone()),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ThemesList {
    /// NOTE: Themes must be saved in the format {theme_name}:{theme_mode}
    pub themes: HashSet<String>,
    pub current_theme: String,
}

impl Default for ThemesList {
    fn default() -> Self {
        let mut themes = HashSet::new();
        themes.insert("Default:light".to_string());
        themes.insert("Default:dark".to_string());

        Self {
            themes,
            current_theme: "Default:light".to_string(),
        }
    }
}
