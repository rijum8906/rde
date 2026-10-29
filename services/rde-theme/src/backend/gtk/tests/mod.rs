//! # GTK Adapter Test Fixtures
//!
//! The Qt fixtures live in the sibling `backend::qt::tests` module, whose
//! visibility is scoped to that subtree, so the GTK tests intentionally keep
//! their own tiny copy instead of widening the Qt module's visibility.

mod adapter;
mod css;
mod settings;

use crate::{
    backend::material::compute_color_roles,
    domain::{
        identity::{ThemeId, VariantId},
        manifest::{ContrastLevel, ThemeMode},
        resolved::{
            Color, ColorRoles, ColorSeeds, Motion, ResolvedTheme, Shape, Typography, VariantKind,
        },
    },
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
    theme_with_variant("dark")
}

/// Builds a published payload with the given variant id.
///
/// Used to exercise the dark-preference decision without duplicating the whole
/// payload in each test.
pub(crate) fn theme_with_variant(variant: &str) -> ResolvedTheme {
    ResolvedTheme {
        schema_version: 1,
        theme_id: ThemeId::builtin_dynamic(),
        variant: VariantId::new(variant).unwrap(),
        kind: VariantKind::Dynamic,
        colors: roles(),
        typography: Typography::default(),
        shape: Shape::default(),
        motion: Motion::default(),
    }
}
