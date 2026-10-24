//! # qt5ct / qt6ct Color Schemes
//!
//! Renders qt5ct and qt6ct color schemes and activates them in the tool
//! configuration.

use std::path::Path;

use crate::domain::palette::Palette;

use super::{
    ini::IniDocument,
    palette::{QtColorGroup, QtPalette},
};

/// Renders a qt5ct/qt6ct color scheme file.
///
/// # Parameters
/// - `palette`: Material 3 palette of the active theme and scheme
///
/// # Returns
/// The complete `[ColorScheme]` document.
pub(crate) fn render_scheme(palette: &Palette) -> String {
    let active = QtPalette::new(palette, QtColorGroup::Active);
    let inactive = QtPalette::new(palette, QtColorGroup::Inactive);
    let disabled = QtPalette::new(palette, QtColorGroup::Disabled);

    format!(
        "[ColorScheme]\nactive_colors={}\ninactive_colors={}\ndisabled_colors={}\n",
        active.to_scheme_list(),
        inactive.to_scheme_list(),
        disabled.to_scheme_list()
    )
}

/// Activates a generated color scheme in an existing qt5ct/qt6ct config.
///
/// Only the two keys that select a custom palette are changed; style, fonts,
/// icons, and every other user setting are preserved.
///
/// # Parameters
/// - `existing`: current configuration contents, empty when the file is absent
/// - `scheme_path`: absolute path of the generated scheme file
///
/// # Returns
/// The updated configuration document.
pub(crate) fn activate_config(existing: &str, scheme_path: &Path) -> String {
    let mut document = IniDocument::parse(existing);

    document.set(
        "Appearance",
        "color_scheme_path",
        &scheme_path.display().to_string(),
    );
    document.set("Appearance", "custom_palette", "true");

    document.to_document()
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
            .palette("#FF6200", ColorScheme::Dark)
            .expect("palette generation")
    }

    #[test]
    fn scheme_document_has_all_three_groups() {
        let document = render_scheme(&palette());

        assert!(document.starts_with("[ColorScheme]\n"));
        for group in ["active_colors=", "inactive_colors=", "disabled_colors="] {
            assert!(document.contains(group), "{group} must be written");
        }

        let active_line = document
            .lines()
            .find(|line| line.starts_with("active_colors="))
            .expect("active colors");
        let colors: Vec<&str> = active_line
            .trim_start_matches("active_colors=")
            .split(", ")
            .collect();
        assert_eq!(colors.len(), 21);
    }

    #[test]
    fn activation_sets_only_the_custom_palette_keys() {
        let existing =
            "[Appearance]\nstyle=Fusion\nicon_theme=Papirus\n\n[Fonts]\ngeneral=Inter,10\n";
        let document = activate_config(existing, Path::new("/tmp/colors/RdeM3.conf"));

        let parsed = IniDocument::parse(&document);
        assert_eq!(
            parsed.get("Appearance", "color_scheme_path"),
            Some("/tmp/colors/RdeM3.conf")
        );
        assert_eq!(parsed.get("Appearance", "custom_palette"), Some("true"));
        assert_eq!(parsed.get("Appearance", "style"), Some("Fusion"));
        assert_eq!(parsed.get("Appearance", "icon_theme"), Some("Papirus"));
        assert_eq!(parsed.get("Fonts", "general"), Some("Inter,10"));
    }

    #[test]
    fn activation_creates_the_appearance_section_when_missing() {
        let document = activate_config("", Path::new("/home/u/.config/qt5ct/colors/RdeM3.conf"));

        assert_eq!(
            document,
            "[Appearance]\ncolor_scheme_path=/home/u/.config/qt5ct/colors/RdeM3.conf\ncustom_palette=true\n"
        );
    }
}
