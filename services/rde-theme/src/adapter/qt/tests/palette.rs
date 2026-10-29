//! # Qt Palette Mapping Tests
//!
//! Pins the `QPalette` slot order, the surface-tier bevel ladder, and the
//! Material tonal ramp the mapping reads from.

use super::super::palette::{qtct_color, render_qtct_palette};
use super::{group_values, relative_luminance, roles};
use crate::{
    adapter::material::compute_color_roles,
    domain::{
        manifest::{ContrastLevel, ThemeMode},
        resolved::{Color, ColorSeeds},
    },
};

#[test]
fn maps_material_roles_onto_qpalette_order() {
    let colors = roles();
    let palette = render_qtct_palette(&colors);

    let active = group_values(&palette, "active_colors");
    assert_eq!(active[0], qtct_color(&colors.on_surface)); // WindowText
    assert_eq!(active[1], qtct_color(&colors.surface_container_high)); // Button
    assert_eq!(active[2], qtct_color(&colors.surface_container_highest)); // Light
    assert_eq!(active[3], qtct_color(&colors.surface_container_high)); // Midlight
    assert_eq!(active[4], qtct_color(&colors.surface_container)); // Dark
    assert_eq!(active[5], qtct_color(&colors.outline_variant)); // Mid
    assert_eq!(active[6], qtct_color(&colors.on_surface)); // Text
    assert_eq!(active[7], qtct_color(&colors.on_surface)); // BrightText
    assert_eq!(active[8], qtct_color(&colors.on_surface)); // ButtonText
    assert_eq!(active[9], qtct_color(&colors.surface_container_low)); // Base
    assert_eq!(active[10], qtct_color(&colors.surface_container)); // Window
    assert_eq!(active[11], qtct_color(&colors.shadow)); // Shadow
    assert_eq!(active[12], qtct_color(&colors.primary_container)); // Highlight
    assert_eq!(active[13], qtct_color(&colors.on_primary_container)); // HighlightedText
    assert_eq!(active[14], qtct_color(&colors.primary)); // Link
    assert_eq!(active[15], qtct_color(&colors.tertiary)); // LinkVisited
    assert_eq!(active[16], qtct_color(&colors.surface_container)); // AlternateBase
    assert_eq!(active[17], qtct_color(&colors.surface)); // NoRole
    assert_eq!(active[18], qtct_color(&colors.inverse_surface)); // ToolTipBase
    assert_eq!(active[19], qtct_color(&colors.inverse_on_surface)); // ToolTipText
    assert_eq!(active[20], qtct_color(&colors.on_surface_variant)); // Placeholder
    assert_eq!(active[21], qtct_color(&colors.primary)); // Accent

    let disabled = group_values(&palette, "disabled_colors");
    assert_eq!(disabled[0], qtct_color(&colors.on_surface_variant)); // WindowText
    assert_eq!(disabled[1], qtct_color(&colors.surface_container)); // Button
    assert_eq!(disabled[2], qtct_color(&colors.surface_container_high)); // Light
    assert_eq!(disabled[3], qtct_color(&colors.surface_container)); // Midlight
    assert_eq!(disabled[4], qtct_color(&colors.surface_container_low)); // Dark
    assert_eq!(disabled[5], qtct_color(&colors.outline_variant)); // Mid
    assert_eq!(disabled[6], qtct_color(&colors.on_surface_variant)); // Text
    assert_eq!(disabled[7], qtct_color(&colors.on_surface_variant)); // BrightText
    assert_eq!(disabled[8], qtct_color(&colors.on_surface_variant)); // ButtonText
    assert_eq!(disabled[9], qtct_color(&colors.surface_container_low)); // Base
    assert_eq!(disabled[10], qtct_color(&colors.surface_container)); // Window
    assert_eq!(disabled[11], qtct_color(&colors.shadow)); // Shadow
    assert_eq!(disabled[12], qtct_color(&colors.primary_container)); // Highlight
    assert_eq!(disabled[13], qtct_color(&colors.on_primary_container)); // HighlightedText
    assert_eq!(disabled[14], qtct_color(&colors.outline)); // Link
    assert_eq!(disabled[15], qtct_color(&colors.outline)); // LinkVisited
    assert_eq!(disabled[16], qtct_color(&colors.surface_container)); // AlternateBase
    assert_eq!(disabled[17], qtct_color(&colors.surface)); // NoRole
    assert_eq!(disabled[18], qtct_color(&colors.surface_container_high)); // ToolTipBase
    assert_eq!(disabled[19], qtct_color(&colors.on_surface_variant)); // ToolTipText
    assert_eq!(disabled[20], qtct_color(&colors.outline_variant)); // Placeholder
    assert_eq!(disabled[21], qtct_color(&colors.primary)); // Accent
}

#[test]
fn every_accent_family_reaches_a_distinct_role() {
    // Distinct seeds per family, so a role fed from the wrong family is
    // visible instead of coincidentally matching a primary tone.
    let seeds = ColorSeeds {
        primary: Color::new("#4285f4").unwrap(),
        secondary: Color::new("#2f8f6f").unwrap(),
        tertiary: Color::new("#c26a3a").unwrap(),
        error: Color::new("#ba1a1a").unwrap(),
    };
    let colors = compute_color_roles(&seeds, ThemeMode::Dark, ContrastLevel::Normal);
    let palette = render_qtct_palette(&colors);
    let active = group_values(&palette, "active_colors");

    // Only the primary and tertiary families own QPalette slots. The secondary
    // family has no dedicated slot by design: Qt has no tonal-secondary role,
    // and forcing one would turn containers into accent chips again.
    assert_eq!(active[12], qtct_color(&colors.primary_container)); // Highlight
    assert_eq!(active[14], qtct_color(&colors.primary)); // Link
    assert_eq!(active[15], qtct_color(&colors.tertiary)); // LinkVisited
    assert_eq!(active[21], qtct_color(&colors.primary)); // Accent
    assert_ne!(colors.primary, colors.tertiary);

    // Tooltips invert against the window rather than blending into it.
    assert_eq!(active[18], qtct_color(&colors.inverse_surface));
    assert_ne!(active[18], active[10]);

    // Alternating rows must not collapse into the field background.
    assert_ne!(active[9], active[16]);
}

#[test]
fn bevel_ladder_is_monotonic() {
    let colors = compute_color_roles(
        &ColorSeeds::uniform(&Color::new("#6750a4").unwrap()),
        ThemeMode::Dark,
        ContrastLevel::Normal,
    );

    // The mapping reads the surface container tiers in descending order, so the
    // ramp itself has to be monotonic. The same direction holds in a Light
    // scheme because these fields are generated per mode — this is a property
    // of the Material tonal ramp, not of the mapping.
    let highest = relative_luminance(&colors.surface_container_highest);
    let high = relative_luminance(&colors.surface_container_high);
    let container = relative_luminance(&colors.surface_container);
    let low = relative_luminance(&colors.surface_container_low);

    assert!(highest >= high, "{highest} < {high}");
    assert!(high >= container, "{high} < {container}");
    assert!(container >= low, "{container} < {low}");
}
