//! # KDE Adapter Test Fixtures
//!
//! Shared palette, theme, section, and contrast helpers used by the KDE
//! adapter's test modules.

mod adapter;
mod globals;
mod mapping;
mod scheme;

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

/// Scheme name the test fixtures render under.
pub(crate) static KDE_COLOR_SCHEM_NAME: &str = "RdeM3";

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

/// Returns the block of one section, without its header.
pub(crate) fn section<'a>(content: &'a str, header: &str) -> &'a str {
    let start = content
        .find(&format!("[{header}]"))
        .unwrap_or_else(|| panic!("missing section {header}: {content}"));
    let rest = &content[start + header.len() + 2..];
    let end = rest.find("\n[").unwrap_or(rest.len());
    &rest[..end]
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
