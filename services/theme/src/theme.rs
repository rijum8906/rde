use serde::{Deserialize, Serialize};
use zbus::zvariant::{OwnedValue, Type, Value};

use crate::models::ThemeMode;

#[derive(Debug, Clone, Serialize, Deserialize, Type, Value, PartialEq, OwnedValue)]
pub struct ThemeColors {
    // ===== PRIMARY =====
    pub primary: String,
    pub on_primary: String,
    pub primary_container: String,
    pub on_primary_container: String,

    // ===== SECONDARY =====
    pub secondary: String,
    pub on_secondary: String,
    pub secondary_container: String,
    pub on_secondary_container: String,

    // ===== TERTIARY =====
    pub tertiary: String,
    pub on_tertiary: String,
    pub tertiary_container: String,
    pub on_tertiary_container: String,

    // ===== ERROR =====
    pub error: String,
    pub on_error: String,
    pub error_container: String,
    pub on_error_container: String,

    // ===== SURFACE =====
    pub surface: String,
    pub on_surface: String,
    pub surface_variant: String,
    pub on_surface_variant: String,

    // ===== BACKGROUND =====
    pub background: String,
    pub on_background: String,

    // ===== OUTLINE =====
    pub outline: String,
    pub outline_variant: String,

    // ===== SURFACE TINTS =====
    pub surface_tint: String,
    pub scrim: String,

    // ===== INVERSE =====
    pub inverse_surface: String,
    pub inverse_on_surface: String,
    pub inverse_primary: String,

    // ===== SHADOW =====
    pub shadow: String,

    // ===== SURFACE CONTAINER (For cards, dialogs) =====
    pub surface_container: String,
    pub surface_container_low: String,
    pub surface_container_high: String,
    pub surface_container_highest: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Value, PartialEq, OwnedValue)]
pub struct ThemeTypography {
    // ===== FONT FAMILIES =====
    pub family: String,
    pub family_mono: String,

    // ===== SIZES =====
    pub size_xs: String,
    pub size_sm: String,
    pub size_md: String,
    pub size_lg: String,
    pub size_xl: String,

    // ===== WEIGHTS =====
    pub weight_light: String,
    pub weight_regular: String,
    pub weight_medium: String,
    pub weight_bold: String,

    // ===== LINE HEIGHTS =====
    pub line_height: String,

    // ===== LETTER SPACING =====
    pub letter_spacing: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Value, PartialEq, OwnedValue)]
pub struct ThemeSizing {
    pub xxs: String,
    pub xs: String,
    pub sm: String,
    pub md: String,
    pub lg: String,
    pub xl: String,
    pub xxl: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type, Value, PartialEq, OwnedValue)]
pub struct Theme {
    // ===== BASIC INFO =====
    pub name: String,
    pub author: String,
    pub version: String,
    pub mode: ThemeMode,

    // ===== COLORS =====
    pub colors: ThemeColors,

    // ===== TYPOGRAPHY =====
    pub typography: ThemeTypography,

    // ===== SPACING AND RADIUS =====
    pub spacing: ThemeSizing,
    pub radius: ThemeSizing,
}
