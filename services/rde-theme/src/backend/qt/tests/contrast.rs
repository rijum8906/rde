//! # Qt Palette Contrast Tests
//!
//! Guards that every text role survives on the background the mapping pairs it
//! with, in both appearances and at every contrast level.

use super::contrast_ratio;
use crate::{
    backend::material::compute_color_roles,
    domain::{
        manifest::{ContrastLevel, ThemeMode},
        resolved::{Color, ColorSeeds},
    },
};

#[test]
fn semantic_text_stays_readable_on_its_background() {
    let seeds = ColorSeeds::uniform(&Color::new("#6750a4").unwrap());

    for (mode, contrast) in [
        (ThemeMode::Dark, ContrastLevel::Normal),
        (ThemeMode::Light, ContrastLevel::Normal),
        (ThemeMode::Dark, ContrastLevel::High),
        (ThemeMode::Light, ContrastLevel::High),
    ] {
        let colors = compute_color_roles(&seeds, mode, contrast);

        // Window text, button text, selected text, and tooltip text must all
        // clear WCAG AA for body text on their own background.
        for (label, foreground, background) in [
            ("WindowText/Window", &colors.on_surface, &colors.surface),
            (
                "Text/Window (active)",
                &colors.on_surface,
                &colors.surface_container,
            ),
            (
                "ButtonText/Button",
                &colors.on_surface,
                &colors.surface_container_high,
            ),
            (
                "HighlightedText/Highlight",
                &colors.on_primary_container,
                &colors.primary_container,
            ),
            (
                "ToolTipText/ToolTipBase",
                &colors.inverse_on_surface,
                &colors.inverse_surface,
            ),
            (
                "PlaceholderText/Base",
                &colors.on_surface_variant,
                &colors.surface_container_low,
            ),
        ] {
            let ratio = contrast_ratio(foreground, background);
            assert!(
                ratio >= 4.5,
                "{label} in {mode:?}/{contrast:?} is only {ratio:.2}:1 ({} on {})",
                foreground.as_str(),
                background.as_str()
            );
        }
    }
}
