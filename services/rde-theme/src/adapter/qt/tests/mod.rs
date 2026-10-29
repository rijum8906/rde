//! # Qt Adapter Test Fixtures
//!
//! Shared palette, theme, and contrast helpers used by the adapter, palette,
//! and contrast test modules.

mod adapter;
mod contrast;
mod palette;

use crate::{
    domain::{
        identity::{ThemeId, VariantId},
        manifest::{ContrastLevel, ThemeMode},
        resolved::{
            Color, ColorRoles, ColorSeeds, Motion, ResolvedTheme, Shape, Typography, VariantKind,
        },
    },
    material::compute_color_roles,
};

/// Builds a deterministic palette for the assertions below.
pub(crate) fn roles() -> ColorRoles {
    compute_color_roles(
        &ColorSeeds::uniform(&Color::new("#6750a4").unwrap()),
        ThemeMode::Dark,
        ContrastLevel::Normal,
    )
}

/// Builds the published payload the adapter renders.
pub(crate) fn theme() -> ResolvedTheme {
    ResolvedTheme {
        schema_version: 1,
        theme_id: ThemeId::builtin_dynamic(),
        variant: VariantId::new("dark").unwrap(),
        kind: VariantKind::Dynamic,
        colors: roles(),
        typography: Typography::default(),
        shape: Shape::default(),
        motion: Motion::default(),
    }
}

/// Returns the comma-separated values of one group line.
pub(crate) fn group_values<'a>(palette: &'a str, key: &str) -> Vec<&'a str> {
    palette
        .lines()
        .find_map(|line| line.strip_prefix(&format!("{key}=")))
        .unwrap_or_else(|| panic!("missing {key}: {palette}"))
        .split(", ")
        .collect()
}

/// Relative luminance of an sRGB color, per WCAG 2.1.
pub(crate) fn relative_luminance(color: &Color) -> f64 {
    let rgb = color.as_str().trim_start_matches('#');
    let channel = |offset: usize| -> f64 {
        let value = u8::from_str_radix(&rgb[offset..offset + 2], 16).unwrap_or(0);
        let srgb = f64::from(value) / 255.0;
        if srgb <= 0.039_28 {
            srgb / 12.92
        } else {
            ((srgb + 0.055) / 1.055).powf(2.4)
        }
    };

    0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
}

/// WCAG 2.1 contrast ratio between two opaque colors.
pub(crate) fn contrast_ratio(foreground: &Color, background: &Color) -> f64 {
    let a = relative_luminance(foreground);
    let b = relative_luminance(background);
    let (lighter, darker) = if a >= b { (a, b) } else { (b, a) };
    (lighter + 0.05) / (darker + 0.05)
}
