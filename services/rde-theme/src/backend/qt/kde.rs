//! # KDE Color Schemes
//!
//! Renders the standalone KDE color scheme and merges the same color groups into
//! `kdeglobals`.

use crate::domain::palette::Palette;

use super::{QT_COLOR_SCHEME_NAME, ini::IniDocument, palette::format_rgb};

/// Human-readable name of the generated color scheme.
const KDE_COLOR_SCHEME_DISPLAY_NAME: &str = "RDE Material 3";

/// A KDE color group with its ordered `key -> color` entries.
type ColorGroup = (&'static str, Vec<(&'static str, u32)>);

/// Renders a standalone KDE `.colors` document.
///
/// # Parameters
/// - `palette`: Material 3 palette of the active theme and scheme
///
/// # Returns
/// The complete color scheme file content.
pub(crate) fn render_color_scheme(palette: &Palette) -> String {
    let mut document = String::new();

    // Step 1: Emit every color group in a stable order.
    for (group, entries) in color_groups(palette) {
        document.push_str(&format!("[{group}]\n"));
        for (key, color) in entries {
            document.push_str(&format!("{key}={}\n", format_rgb(color)));
        }
    }

    // Step 2: Identify the scheme and provide the titlebar colors.
    document.push_str(&format!(
        "[General]\nColorScheme={QT_COLOR_SCHEME_NAME}\nName={KDE_COLOR_SCHEME_DISPLAY_NAME}\n"
    ));
    document.push_str("[WM]\n");
    for (key, color) in window_manager_entries(palette) {
        document.push_str(&format!("{key}={}\n", format_rgb(color)));
    }

    document
}

/// Merges the generated color groups into an existing `kdeglobals` document.
///
/// # Parameters
/// - `existing`: current `kdeglobals` contents, empty when the file is absent
/// - `palette`: Material 3 palette of the active theme and scheme
///
/// # Returns
/// The updated document, with every unrelated setting preserved.
pub(crate) fn merge_kdeglobals(existing: &str, palette: &Palette) -> String {
    let mut document = IniDocument::parse(existing);

    // Step 1: Update the color groups used by KDE applications.
    for (group, entries) in color_groups(palette) {
        for (key, color) in entries {
            document.set(group, key, &format_rgb(color));
        }
    }

    // Step 2: Update titlebar colors and select the scheme.
    for (key, color) in window_manager_entries(palette) {
        document.set("WM", key, &format_rgb(color));
    }
    document.set("General", "ColorScheme", QT_COLOR_SCHEME_NAME);

    // Step 3: Pin the Plasma 6 accent color to the theme's primary color.
    document.set("General", "AccentColor", &format_rgb(palette.primary));

    document.to_document()
}

/// Builds every KDE color group for a Material 3 palette.
fn color_groups(palette: &Palette) -> Vec<ColorGroup> {
    vec![
        (
            "Colors:Window",
            window_like_entries(palette, palette.surface, palette.surface_container_low),
        ),
        (
            "Colors:View",
            window_like_entries(
                palette,
                palette.surface_container_lowest,
                palette.surface_container_low,
            ),
        ),
        (
            "Colors:Button",
            window_like_entries(
                palette,
                palette.surface_container,
                palette.surface_container_low,
            ),
        ),
        ("Colors:Selection", selection_entries(palette)),
        ("Colors:Tooltip", tooltip_entries(palette)),
        (
            "Colors:Complementary",
            window_like_entries(
                palette,
                palette.inverse_surface,
                palette.surface_container_highest,
            )
            .into_iter()
            .map(|(key, color)| {
                // Complementary surfaces need inverse-capable foregrounds.
                let color = match key {
                    "ForegroundNormal" | "ForegroundInactive" => palette.inverse_on_surface,
                    "ForegroundActive" | "ForegroundLink" | "ForegroundVisited"
                    | "ForegroundNeutral" | "ForegroundPositive" | "DecorationFocus"
                    | "DecorationHover" => palette.inverse_primary,
                    _ => color,
                };
                (key, color)
            })
            .collect(),
        ),
        (
            "Colors:Header",
            window_like_entries(
                palette,
                palette.surface_container,
                palette.surface_container_high,
            ),
        ),
    ]
}

/// Builds the entries shared by window-like groups (Window, View, Button, ...).
fn window_like_entries(
    palette: &Palette,
    background: u32,
    background_alternate: u32,
) -> Vec<(&'static str, u32)> {
    vec![
        ("BackgroundNormal", background),
        ("BackgroundAlternate", background_alternate),
        ("ForegroundNormal", palette.on_surface),
        ("ForegroundInactive", palette.on_surface_variant),
        ("ForegroundActive", palette.primary),
        ("ForegroundLink", palette.primary),
        ("ForegroundVisited", palette.tertiary),
        ("ForegroundNegative", palette.error),
        ("ForegroundNeutral", palette.tertiary),
        ("ForegroundPositive", palette.primary),
        ("DecorationFocus", palette.primary),
        ("DecorationHover", palette.primary),
    ]
}

/// Builds the selection group, which uses primary colors for full contrast.
fn selection_entries(palette: &Palette) -> Vec<(&'static str, u32)> {
    vec![
        ("BackgroundNormal", palette.primary),
        ("BackgroundAlternate", palette.primary_container),
        ("ForegroundNormal", palette.on_primary),
        ("ForegroundInactive", palette.on_primary),
        ("ForegroundActive", palette.on_primary),
        ("ForegroundLink", palette.on_primary),
        ("ForegroundVisited", palette.on_primary),
        ("ForegroundNegative", palette.on_error),
        ("ForegroundNeutral", palette.on_primary),
        ("ForegroundPositive", palette.on_primary),
        ("DecorationFocus", palette.on_primary),
        ("DecorationHover", palette.on_primary),
    ]
}

/// Builds the tooltip group from the inverse (high-contrast) surface colors.
fn tooltip_entries(palette: &Palette) -> Vec<(&'static str, u32)> {
    vec![
        ("BackgroundNormal", palette.inverse_surface),
        ("BackgroundAlternate", palette.inverse_surface),
        ("ForegroundNormal", palette.inverse_on_surface),
        ("ForegroundInactive", palette.inverse_on_surface),
        ("ForegroundActive", palette.inverse_primary),
        ("ForegroundLink", palette.inverse_primary),
        ("ForegroundVisited", palette.inverse_primary),
        ("ForegroundNegative", palette.error),
        ("ForegroundNeutral", palette.inverse_primary),
        ("ForegroundPositive", palette.inverse_primary),
        ("DecorationFocus", palette.inverse_primary),
        ("DecorationHover", palette.inverse_primary),
    ]
}

/// Builds the titlebar (`[WM]`) entries.
fn window_manager_entries(palette: &Palette) -> Vec<(&'static str, u32)> {
    vec![
        ("activeBackground", palette.surface_container),
        ("activeForeground", palette.on_surface),
        ("activeBlend", palette.primary),
        ("inactiveBackground", palette.surface),
        ("inactiveForeground", palette.on_surface_variant),
        ("inactiveBlend", palette.surface_container_high),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        backend::{MaterialBackend, ThemeBackend},
        domain::theme::ColorScheme,
    };

    fn palette() -> Palette {
        MaterialBackend
            .palette("#6DD6DA", ColorScheme::Dark)
            .expect("palette generation")
    }

    #[test]
    fn color_scheme_contains_every_group_and_the_scheme_name() {
        let document = render_color_scheme(&palette());

        for group in [
            "Colors:Window",
            "Colors:View",
            "Colors:Button",
            "Colors:Selection",
            "Colors:Tooltip",
            "Colors:Complementary",
            "Colors:Header",
            "General",
            "WM",
        ] {
            assert!(
                document.contains(&format!("[{group}]")),
                "{group} must be written"
            );
        }
        assert!(document.contains("ColorScheme=RdeM3"));
        assert!(document.contains(&format!(
            "BackgroundNormal={}\n",
            format_rgb(palette().surface)
        )));
        assert!(document.contains(&format!(
            "[Colors:Selection]\nBackgroundNormal={}\n",
            format_rgb(palette().primary)
        )));
    }

    #[test]
    fn kdeglobals_merge_preserves_unrelated_settings() {
        let existing = "# user settings\n[KDE]\ncontrast=4\n\n[General]\nColorScheme=BreezeDark\n";
        let document = merge_kdeglobals(existing, &palette());
        let parsed = IniDocument::parse(&document);

        assert!(document.starts_with("# user settings\n[KDE]\ncontrast=4"));
        assert_eq!(parsed.get("KDE", "contrast"), Some("4"));
        assert_eq!(parsed.get("General", "ColorScheme"), Some("RdeM3"));
        assert_eq!(
            parsed.get("Colors:Window", "BackgroundNormal"),
            Some(format_rgb(palette().surface).as_str())
        );
        assert_eq!(
            parsed.get("General", "AccentColor"),
            Some(format_rgb(palette().primary).as_str())
        );
    }

    #[test]
    fn kdeglobals_merge_is_idempotent() {
        let once = merge_kdeglobals("", &palette());

        assert_eq!(merge_kdeglobals(&once, &palette()), once);
    }
}
