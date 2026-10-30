//! # GTK settings.ini
//!
//! Selects the generated theme and the dark preference in
//! `gtk-3.0/settings.ini` and `gtk-4.0/settings.ini`, preserving every other
//! key the user or the toolkit wrote.

use std::path::Path;

use super::paths::GtkTool;
use crate::domain::resolved::{Color, ResolvedTheme};

/// Section of a GTK settings document that holds the appearance keys.
const SETTINGS_SECTION: &str = "Settings";

/// Key selecting the theme whose `gtk.css` GTK loads.
const THEME_KEY: &str = "gtk-theme-name";

/// Whether the resolved theme is a dark appearance.
///
/// # Parameters
/// - `theme`: published payload
///
/// # Returns
/// `true` when the variant carries `dark`, `false` when it carries `light`,
/// and otherwise the decision derived from the surface luminance, so custom
/// variant names (`midnight`, `sepia`, …) still land on the right side.
pub(crate) fn prefers_dark(theme: &ResolvedTheme) -> bool {
    // Step 1: The conventional variant names are the cheapest signal.
    let variant = theme.variant.to_string();
    if variant.contains("dark") {
        return true;
    }
    if variant.contains("light") {
        return false;
    }

    // Step 2: Custom variants fall back to Material's own surface tone.
    relative_luminance(&theme.colors.surface) < 0.5
}

/// Renders a complete settings document for a fresh configuration.
///
/// # Parameters
/// - `theme_name`: generation-scoped theme name written to `gtk-theme-name`
/// - `prefer_dark`: whether GTK should prefer the dark appearance
pub(crate) fn render_settings_ini(theme_name: &str, prefer_dark: bool) -> String {
    format!(
        "[{SETTINGS_SECTION}]\n{THEME_KEY}={theme_name}\n{}={prefer_dark}\n",
        GtkTool::settings_key_dark()
    )
}

/// Updates the appearance keys in a GTK settings document.
///
/// Everything else (fonts, cursor theme, toolkit flags, comments) is
/// preserved, so switching themes never resets the user's configuration.
///
/// # Parameters
/// - `existing`: current `settings.ini` content, usually read from disk
/// - `theme_name`: generation-scoped theme name written to `gtk-theme-name`
/// - `prefer_dark`: whether GTK should prefer the dark appearance
pub(crate) fn merge_settings_ini(existing: &str, theme_name: &str, prefer_dark: bool) -> String {
    let entries = [
        (THEME_KEY, theme_name.to_string()),
        (GtkTool::settings_key_dark(), prefer_dark.to_string()),
    ];
    let mut lines: Vec<String> = existing.lines().map(str::to_string).collect();
    let mut written = [false; 2];

    let header = lines
        .iter()
        .position(|line| line.trim() == format!("[{SETTINGS_SECTION}]"));

    match header {
        // Step 1: Replace the owned keys inside an existing [Settings] group.
        Some(header_index) => {
            let section_end = lines[header_index + 1..]
                .iter()
                .position(|line| is_section_header(line))
                .map_or(lines.len(), |offset| header_index + 1 + offset);

            for line in lines.iter_mut().take(section_end).skip(header_index + 1) {
                let trimmed = line.trim().to_string();
                let Some((key, _)) = trimmed.split_once('=') else {
                    continue;
                };
                let key = key.trim();
                for (index, (entry_key, entry_value)) in entries.iter().enumerate() {
                    if key == *entry_key {
                        *line = format!("{entry_key}={entry_value}");
                        written[index] = true;
                    }
                }
            }

            // Step 2: Append the keys the section was missing.
            let mut inserted = 0;
            for (index, (entry_key, entry_value)) in entries.iter().enumerate() {
                if written[index] {
                    continue;
                }
                lines.insert(section_end + inserted, format!("{entry_key}={entry_value}"));
                inserted += 1;
            }
        }
        // Step 3: Append the whole group when the toolkit has no config yet.
        None => {
            if lines.last().is_some_and(|line| !line.trim().is_empty()) {
                lines.push(String::new());
            }
            lines.extend(
                render_settings_ini(theme_name, prefer_dark)
                    .lines()
                    .map(str::to_string),
            );
        }
    }

    let mut out = lines.join("\n");
    out.push('\n');
    out
}

/// Whether [line] is an INI section header.
fn is_section_header(line: &str) -> bool {
    let trimmed = line.trim();
    trimmed.len() > 2 && trimmed.starts_with('[') && trimmed.ends_with(']')
}

/// Reads a file, treating "missing" and "unreadable" as empty content.
pub(crate) fn read_optional(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap_or_default()
}

/// Relative luminance of an sRGB color, per WCAG 2.1.
fn relative_luminance(color: &Color) -> f64 {
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
