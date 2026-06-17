use std::sync::LazyLock;

use crate::{
    models::ThemeMode,
    theme::{Theme, ThemeColors, ThemeSizing, ThemeTypography},
};

// ===== LIGHT THEME =====
pub static DEFAULT_LIGHT_THEME: LazyLock<Theme> = LazyLock::new(|| Theme {
    name: "Default".to_string(),
    author: "RDE".to_string(),
    version: "1.0.0".to_string(),
    mode: ThemeMode::Light,

    // ===== COLORS =====
    colors: ThemeColors {
        // Primary
        primary: "#6750A4".to_string(),
        on_primary: "#FFFFFF".to_string(),
        primary_container: "#EADDFF".to_string(),
        on_primary_container: "#21005D".to_string(),

        // Secondary
        secondary: "#625B71".to_string(),
        on_secondary: "#FFFFFF".to_string(),
        secondary_container: "#E8DEF8".to_string(),
        on_secondary_container: "#1D192B".to_string(),

        // Tertiary
        tertiary: "#7D5260".to_string(),
        on_tertiary: "#FFFFFF".to_string(),
        tertiary_container: "#FFD8E4".to_string(),
        on_tertiary_container: "#31111D".to_string(),

        // Error
        error: "#BA1A1A".to_string(),
        on_error: "#FFFFFF".to_string(),
        error_container: "#FFDAD6".to_string(),
        on_error_container: "#410002".to_string(),

        // Surface
        surface: "#FEF7FF".to_string(),
        on_surface: "#1D1B20".to_string(),
        surface_variant: "#E7E0EC".to_string(),
        on_surface_variant: "#49454F".to_string(),

        // Background
        background: "#FFFBFE".to_string(),
        on_background: "#1D1B20".to_string(),

        // Outline
        outline: "#79747E".to_string(),
        outline_variant: "#CAC4D0".to_string(),

        // Surface tints
        surface_tint: "#6750A4".to_string(),
        scrim: "#000000".to_string(),

        // Inverse
        inverse_surface: "#322F35".to_string(),
        inverse_on_surface: "#F5EFF7".to_string(),
        inverse_primary: "#D0BCFF".to_string(),

        // Shadow
        shadow: "#000000".to_string(),

        // Surface containers
        surface_container: "#F3EDF7".to_string(),
        surface_container_low: "#F7F2FA".to_string(),
        surface_container_high: "#ECE6F0".to_string(),
        surface_container_highest: "#E6E0E9".to_string(),
    },

    // ===== TYPOGRAPHY =====
    typography: ThemeTypography {
        family: "Inter".to_string(),
        family_mono: "JetBrains Mono".to_string(),

        // Font sizes (in pixels)
        size_xs: "11".to_string(),
        size_sm: "13".to_string(),
        size_md: "14".to_string(),
        size_lg: "16".to_string(),
        size_xl: "20".to_string(),

        // Font weights
        weight_light: "300".to_string(),
        weight_regular: "400".to_string(),
        weight_medium: "500".to_string(),
        weight_bold: "700".to_string(),

        // Spacing
        line_height: "1.5".to_string(),
        letter_spacing: "0".to_string(),
    },

    // ===== SPACING =====
    spacing: ThemeSizing {
        xxs: "2".to_string(),
        xs: "4".to_string(),
        sm: "8".to_string(),
        md: "16".to_string(),
        lg: "24".to_string(),
        xl: "32".to_string(),
        xxl: "48".to_string(),
    },

    // ===== BORDER RADIUS =====
    radius: ThemeSizing {
        xxs: "2".to_string(),
        xs: "4".to_string(),
        sm: "8".to_string(),
        md: "12".to_string(),
        lg: "16".to_string(),
        xl: "24".to_string(),
        xxl: "32".to_string(),
    },
});

// ===== DARK THEME =====
pub static DEFAULT_DARK_THEME: LazyLock<Theme> = LazyLock::new(|| Theme {
    name: "Default".to_string(),
    author: "RDE".to_string(),
    version: "1.0.0".to_string(),
    mode: ThemeMode::Dark,

    // ===== COLORS =====
    colors: ThemeColors {
        // Primary
        primary: "#D0BCFF".to_string(),
        on_primary: "#381E72".to_string(),
        primary_container: "#4F378B".to_string(),
        on_primary_container: "#EADDFF".to_string(),

        // Secondary
        secondary: "#CCC2DC".to_string(),
        on_secondary: "#332D41".to_string(),
        secondary_container: "#4A4458".to_string(),
        on_secondary_container: "#E8DEF8".to_string(),

        // Tertiary
        tertiary: "#EFB8C8".to_string(),
        on_tertiary: "#492532".to_string(),
        tertiary_container: "#633B48".to_string(),
        on_tertiary_container: "#FFD8E4".to_string(),

        // Error
        error: "#FFB4AB".to_string(),
        on_error: "#690005".to_string(),
        error_container: "#93000A".to_string(),
        on_error_container: "#FFDAD6".to_string(),

        // Surface
        surface: "#141218".to_string(),
        on_surface: "#E6E0E9".to_string(),
        surface_variant: "#49454F".to_string(),
        on_surface_variant: "#CAC4D0".to_string(),

        // Background
        background: "#141218".to_string(),
        on_background: "#E6E0E9".to_string(),

        // Outline
        outline: "#938F99".to_string(),
        outline_variant: "#49454F".to_string(),

        // Surface tints
        surface_tint: "#D0BCFF".to_string(),
        scrim: "#000000".to_string(),

        // Inverse
        inverse_surface: "#E6E0E9".to_string(),
        inverse_on_surface: "#141218".to_string(),
        inverse_primary: "#6750A4".to_string(),

        // Shadow
        shadow: "#000000".to_string(),

        // Surface containers
        surface_container: "#211F26".to_string(),
        surface_container_low: "#1D1B20".to_string(),
        surface_container_high: "#2B2930".to_string(),
        surface_container_highest: "#36343B".to_string(),
    },

    // ===== TYPOGRAPHY =====
    typography: ThemeTypography {
        family: "Inter".to_string(),
        family_mono: "JetBrains Mono".to_string(),

        size_xs: "11".to_string(),
        size_sm: "13".to_string(),
        size_md: "14".to_string(),
        size_lg: "16".to_string(),
        size_xl: "20".to_string(),

        weight_light: "300".to_string(),
        weight_regular: "400".to_string(),
        weight_medium: "500".to_string(),
        weight_bold: "700".to_string(),

        line_height: "1.5".to_string(),
        letter_spacing: "0".to_string(),
    },

    // ===== SPACING =====
    spacing: ThemeSizing {
        xxs: "2".to_string(),
        xs: "4".to_string(),
        sm: "8".to_string(),
        md: "16".to_string(),
        lg: "24".to_string(),
        xl: "32".to_string(),
        xxl: "48".to_string(),
    },

    // ===== BORDER RADIUS =====
    radius: ThemeSizing {
        xxs: "2".to_string(),
        xs: "4".to_string(),
        sm: "8".to_string(),
        md: "12".to_string(),
        lg: "16".to_string(),
        xl: "24".to_string(),
        xxl: "32".to_string(),
    },
});

// ===== HELPER FUNCTIONS =====

impl Theme {
    /// Create a light theme with custom accent color
    pub fn light_with_accent(accent: &str) -> Self {
        let mut theme = DEFAULT_LIGHT_THEME.clone();
        theme.colors.primary = accent.to_string();
        theme.colors.surface_tint = accent.to_string();
        theme
    }

    /// Create a dark theme with custom accent color
    pub fn dark_with_accent(accent: &str) -> Self {
        let mut theme = DEFAULT_DARK_THEME.clone();
        theme.colors.primary = accent.to_string();
        theme.colors.surface_tint = accent.to_string();
        theme
    }
}
