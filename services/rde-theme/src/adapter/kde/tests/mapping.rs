//! # KDE Color Mapping Tests
//!
//! Pins which Material role each KDE group slot reads, and that the per-section
//! backgrounds stay on distinct elevation tiers.

use super::{KDE_COLOR_SCHEM_NAME, relative_luminance, roles, section};
use crate::{
    adapter::kde::{color::to_kde_rgb, render_color_scheme},
    domain::{
        manifest::{ContrastLevel, ThemeMode},
        resolved::{Color, ColorSeeds},
    },
    material::compute_color_roles,
};

#[test]
fn maps_surfaces_and_accents_onto_the_groups() {
    let colors = roles();
    let content = render_color_scheme(&colors, KDE_COLOR_SCHEM_NAME);

    // Window text follows the surface roles, and focus/hover carry the accent
    // instead of Breeze's blue.
    let window = section(&content, "Colors:Window");
    assert!(
        window.contains(&format!("BackgroundNormal={}", to_kde_rgb(&colors.surface))),
        "{window}"
    );
    assert!(
        window.contains(&format!(
            "ForegroundInactive={}",
            to_kde_rgb(&colors.on_surface_variant)
        )),
        "{window}"
    );
    assert!(
        window.contains(&format!("DecorationHover={}", to_kde_rgb(&colors.primary))),
        "{window}"
    );

    let view = section(&content, "Colors:View");
    assert!(
        view.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container_lowest)
        )),
        "{view}"
    );

    // The elevation ladder: a button is one tier above the header it sits on,
    // the header one tier above the complementary panel, and View recesses
    // below the complementary panel.
    let button = section(&content, "Colors:Button");
    assert!(
        button.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container_high)
        )),
        "{button}"
    );
    let header = section(&content, "Colors:Header");
    assert!(
        header.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container)
        )),
        "{header}"
    );
    let complementary = section(&content, "Colors:Complementary");
    assert!(
        complementary.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container_low)
        )),
        "{complementary}"
    );

    // The selection group swaps to the accent family on both sides.
    let selection = section(&content, "Colors:Selection");
    assert!(
        selection.contains(&format!("BackgroundNormal={}", to_kde_rgb(&colors.primary))),
        "{selection}"
    );
    assert!(
        selection.contains(&format!(
            "ForegroundNormal={}",
            to_kde_rgb(&colors.on_primary)
        )),
        "{selection}"
    );

    // Tooltips invert like Material 3, and KWin gets its decoration group.
    let tooltip = section(&content, "Colors:Tooltip");
    assert!(
        tooltip.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.inverse_surface)
        )),
        "{tooltip}"
    );
    let wm = section(&content, "WM");
    assert!(wm.contains("activeBackground="), "{wm}");
    assert!(wm.contains("inactiveForeground="), "{wm}");
}

#[test]
fn active_and_neutral_read_from_the_right_roles() {
    let colors = roles();
    let content = render_color_scheme(&colors, KDE_COLOR_SCHEM_NAME);
    let window = section(&content, "Colors:Window");

    // An active row is focus, not a hyperlink: it uses the default text color.
    assert!(
        window.contains(&format!(
            "ForegroundActive={}",
            to_kde_rgb(&colors.on_surface)
        )),
        "{window}"
    );
    assert!(!window.contains(&format!("ForegroundActive={}", to_kde_rgb(&colors.primary))));

    // The warning/modified tone comes from the tertiary family, not the
    // secondary accent that used to render as a link.
    assert!(
        window.contains(&format!(
            "ForegroundNeutral={}",
            to_kde_rgb(&colors.tertiary)
        )),
        "{window}"
    );

    // Material has no success role, so success text is the default foreground.
    assert!(
        window.contains(&format!(
            "ForegroundPositive={}",
            to_kde_rgb(&colors.on_surface)
        )),
        "{window}"
    );
    assert!(!window.contains(&format!(
        "ForegroundPositive={}",
        to_kde_rgb(&colors.tertiary)
    )));

    // The three state slots are distinct in the uniform-seed scheme.
    assert_ne!(colors.on_surface, colors.tertiary);

    // The ladder is real: a button does not share the header background.
    let button = section(&content, "Colors:Button");
    let header = section(&content, "Colors:Header");
    assert!(
        button.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container_high)
        )),
        "{button}"
    );
    assert!(
        header.contains(&format!(
            "BackgroundNormal={}",
            to_kde_rgb(&colors.surface_container)
        )),
        "{header}"
    );
    assert_ne!(
        to_kde_rgb(&colors.surface_container_high),
        to_kde_rgb(&colors.surface_container)
    );
}

#[test]
fn background_ladder_is_monotonic() {
    let seeds = ColorSeeds::uniform(&Color::new("#6750a4").unwrap());

    // The ladder is a property of the Material tonal ramp, not of the mapping:
    // the container tiers climb with elevation in the dark appearance and fall
    // in the light one, because a raised surface is lighter on dark and darker
    // on light. The test guards against reading the tiers out of order.
    let dark = compute_color_roles(&seeds, ThemeMode::Dark, ContrastLevel::Normal);
    let luminance = |color: &Color| relative_luminance(color);
    assert!(luminance(&dark.surface_container_high) >= luminance(&dark.surface_container));
    assert!(luminance(&dark.surface_container) >= luminance(&dark.surface_container_low));
    assert!(luminance(&dark.surface_container_low) >= luminance(&dark.surface_container_lowest));

    let light = compute_color_roles(&seeds, ThemeMode::Light, ContrastLevel::Normal);
    assert!(luminance(&light.surface_container_lowest) >= luminance(&light.surface_container_low));
    assert!(luminance(&light.surface_container_low) >= luminance(&light.surface_container));
    assert!(luminance(&light.surface_container) >= luminance(&light.surface_container_high));

    // Every background the mapping uses is a distinct surface, in both modes.
    for colors in [&dark, &light] {
        let backgrounds = [
            &colors.surface,
            &colors.surface_container_high,
            &colors.surface_container,
            &colors.surface_container_low,
            &colors.surface_container_lowest,
        ];
        for (index, left) in backgrounds.iter().enumerate() {
            for right in backgrounds.iter().skip(index + 1) {
                assert_ne!(left, right, "duplicate background tier: {left:?}");
            }
        }
    }
}
