//! # Qt Palette Mapping
//!
//! Maps semantic color roles onto Qt palette roles for qt5ct, qt6ct, and KDE.

use crate::domain::palette::Palette;

/// Number of Qt palette roles written to qt5ct/qt6ct color schemes.
///
/// This is `QPalette::NColorRoles` on Qt 5.15 (roles 0 through
/// `PlaceholderText`).
pub const QT_COLOR_ROLE_COUNT: usize = 21;

/// Alpha channel applied to [`QtColorRole::PlaceholderText`].
///
/// Qt derives placeholder text from the text color with reduced alpha; using
/// the same convention keeps placeholders visually secondary.
const PLACEHOLDER_ALPHA: u32 = 0x8000_0000;

/// Qt's `QPalette::ColorRole` values in their serialization order.
///
/// The discriminants are significant: qt5ct and qt6ct parse the color list by
/// index, so the order must never be changed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(usize)]
pub enum QtColorRole {
    /// General window text, mapped from `on_surface`.
    WindowText = 0,
    /// Button background, mapped from `surface_container`.
    Button = 1,
    /// Lighter bevel color, mapped from `surface_container_highest`.
    Light = 2,
    /// Mid-light bevel color, mapped from `surface_container_high`.
    Midlight = 3,
    /// Darker bevel color, mapped from `surface_dim`.
    Dark = 4,
    /// Mid bevel color, mapped from `outline_variant`.
    Mid = 5,
    /// Text entry text, mapped from `on_surface`.
    Text = 6,
    /// High-contrast text, mapped from `on_surface`.
    BrightText = 7,
    /// Button text, mapped from `on_surface`.
    ButtonText = 8,
    /// Text entry background, mapped from `surface_container_lowest`.
    Base = 9,
    /// Window background, mapped from `surface`.
    Window = 10,
    /// Shadow color, mapped from `shadow`.
    Shadow = 11,
    /// Selection background, mapped from `primary`.
    Highlight = 12,
    /// Selection text, mapped from `on_primary`.
    HighlightedText = 13,
    /// Hyperlink color, mapped from `primary`.
    Link = 14,
    /// Visited hyperlink color, mapped from `tertiary`.
    LinkVisited = 15,
    /// Alternate list row background, mapped from `surface_container_low`.
    AlternateBase = 16,
    /// Unused role, mapped from `surface`.
    NoRole = 17,
    /// Tooltip background, mapped from `inverse_surface`.
    ToolTipBase = 18,
    /// Tooltip text, mapped from `inverse_on_surface`.
    ToolTipText = 19,
    /// Placeholder text, mapped from `on_surface_variant`.
    PlaceholderText = 20,
}

impl QtColorRole {
    /// Every role in Qt serialization order.
    pub const ALL: [Self; QT_COLOR_ROLE_COUNT] = [
        Self::WindowText,
        Self::Button,
        Self::Light,
        Self::Midlight,
        Self::Dark,
        Self::Mid,
        Self::Text,
        Self::BrightText,
        Self::ButtonText,
        Self::Base,
        Self::Window,
        Self::Shadow,
        Self::Highlight,
        Self::HighlightedText,
        Self::Link,
        Self::LinkVisited,
        Self::AlternateBase,
        Self::NoRole,
        Self::ToolTipBase,
        Self::ToolTipText,
        Self::PlaceholderText,
    ];

    /// Returns the role name as it appears in Qt documentation.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::WindowText => "WindowText",
            Self::Button => "Button",
            Self::Light => "Light",
            Self::Midlight => "Midlight",
            Self::Dark => "Dark",
            Self::Mid => "Mid",
            Self::Text => "Text",
            Self::BrightText => "BrightText",
            Self::ButtonText => "ButtonText",
            Self::Base => "Base",
            Self::Window => "Window",
            Self::Shadow => "Shadow",
            Self::Highlight => "Highlight",
            Self::HighlightedText => "HighlightedText",
            Self::Link => "Link",
            Self::LinkVisited => "LinkVisited",
            Self::AlternateBase => "AlternateBase",
            Self::NoRole => "NoRole",
            Self::ToolTipBase => "ToolTipBase",
            Self::ToolTipText => "ToolTipText",
            Self::PlaceholderText => "PlaceholderText",
        }
    }
}

/// Color group a Qt palette is generated for.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QtColorGroup {
    /// Colors used while the window is focused.
    Active,
    /// Colors used while the window is unfocused.
    Inactive,
    /// Colors used for disabled widgets.
    Disabled,
}

/// Ordered Qt palette generated from a Material 3 palette.
///
/// The internal array is indexed by [`QtColorRole`] discriminants, so writing
/// the color list is a straight iteration in Qt's serialization order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QtPalette {
    /// Packed opaque ARGB colors in Qt role order.
    colors: [u32; QT_COLOR_ROLE_COUNT],
}

impl QtPalette {
    /// Builds a Qt palette for one color group.
    ///
    /// # Parameters
    /// - `palette`: Material 3 palette the theme resolved to
    /// - `group`: active, inactive, or disabled color group
    pub fn new(palette: &Palette, group: QtColorGroup) -> Self {
        let mut colors = [0_u32; QT_COLOR_ROLE_COUNT];

        for role in QtColorRole::ALL {
            colors[role as usize] = match group {
                QtColorGroup::Disabled => disabled_role_color(role, palette),
                QtColorGroup::Active | QtColorGroup::Inactive => active_role_color(role, palette),
            };
        }

        Self { colors }
    }

    /// Returns the color assigned to a Qt role.
    pub fn color(&self, role: QtColorRole) -> u32 {
        self.colors[role as usize]
    }

    /// Returns the colors in Qt serialization order.
    pub fn colors(&self) -> &[u32; QT_COLOR_ROLE_COUNT] {
        &self.colors
    }

    /// Renders the comma-separated `#AARRGGBB` list used by qt5ct and qt6ct.
    ///
    /// `PlaceholderText` keeps Qt's translucent convention; every other role is
    /// fully opaque.
    pub fn to_scheme_list(&self) -> String {
        QtColorRole::ALL
            .into_iter()
            .map(|role| {
                let color = self.color(role);
                let color = if role == QtColorRole::PlaceholderText {
                    (color & !0xFF00_0000) | PLACEHOLDER_ALPHA
                } else {
                    color
                };
                format_qt_color(color)
            })
            .collect::<Vec<_>>()
            .join(", ")
    }

    /// Renders a color as the `r,g,b` triplet used by KDE color schemes.
    pub fn to_kde_rgb(&self, role: QtColorRole) -> String {
        format_rgb(self.color(role))
    }
}

/// Maps a Material 3 role to a Qt role for the active and inactive groups.
fn active_role_color(role: QtColorRole, palette: &Palette) -> u32 {
    match role {
        QtColorRole::WindowText | QtColorRole::Text | QtColorRole::BrightText => palette.on_surface,
        QtColorRole::ButtonText => palette.on_surface,
        QtColorRole::Button => palette.surface_container,
        QtColorRole::Light => palette.surface_container_highest,
        QtColorRole::Midlight => palette.surface_container_high,
        QtColorRole::Dark => palette.surface_dim,
        QtColorRole::Mid => palette.outline_variant,
        QtColorRole::Base => palette.surface_container_lowest,
        QtColorRole::Window => palette.surface,
        QtColorRole::Shadow => palette.shadow,
        QtColorRole::Highlight => palette.primary,
        QtColorRole::HighlightedText => palette.on_primary,
        QtColorRole::Link => palette.primary,
        QtColorRole::LinkVisited => palette.tertiary,
        QtColorRole::AlternateBase => palette.surface_container_low,
        QtColorRole::NoRole => palette.surface,
        QtColorRole::ToolTipBase => palette.inverse_surface,
        QtColorRole::ToolTipText => palette.inverse_on_surface,
        QtColorRole::PlaceholderText => palette.on_surface_variant,
    }
}

/// Maps a Material 3 role to a Qt role for the disabled group.
///
/// Backgrounds keep their active colors; text and links are neutralized with
/// the outline roles so disabled widgets read as inactive without losing the
/// theme's surfaces.
fn disabled_role_color(role: QtColorRole, palette: &Palette) -> u32 {
    match role {
        QtColorRole::WindowText
        | QtColorRole::Text
        | QtColorRole::BrightText
        | QtColorRole::ButtonText
        | QtColorRole::HighlightedText
        | QtColorRole::ToolTipText => palette.outline,
        QtColorRole::Link | QtColorRole::LinkVisited | QtColorRole::PlaceholderText => {
            palette.outline_variant
        }
        other => active_role_color(other, palette),
    }
}

/// Formats a packed color as lowercase `#AARRGGBB` for qt5ct/qt6ct.
fn format_qt_color(argb: u32) -> String {
    format!("#{argb:08x}")
}

/// Formats a packed color as the KDE `r,g,b` triplet.
pub(super) fn format_rgb(argb: u32) -> String {
    format!(
        "{},{},{}",
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF
    )
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
            .palette("#006A6A", ColorScheme::Light)
            .expect("palette generation")
    }

    #[test]
    fn roles_follow_qt_serialization_order() {
        assert_eq!(QtColorRole::ALL.len(), QT_COLOR_ROLE_COUNT);
        for (index, role) in QtColorRole::ALL.into_iter().enumerate() {
            assert_eq!(role as usize, index, "{} is out of order", role.as_str());
        }
        assert_eq!(QtColorRole::Highlight as usize, 12);
        assert_eq!(QtColorRole::PlaceholderText as usize, 20);
    }

    #[test]
    fn active_group_mirrors_the_material_palette() {
        let palette = palette();
        let qt = QtPalette::new(&palette, QtColorGroup::Active);

        assert_eq!(qt.color(QtColorRole::Window), palette.surface);
        assert_eq!(qt.color(QtColorRole::WindowText), palette.on_surface);
        assert_eq!(
            qt.color(QtColorRole::Base),
            palette.surface_container_lowest
        );
        assert_eq!(qt.color(QtColorRole::Button), palette.surface_container);
        assert_eq!(qt.color(QtColorRole::Highlight), palette.primary);
        assert_eq!(qt.color(QtColorRole::HighlightedText), palette.on_primary);
        assert_eq!(qt.color(QtColorRole::ToolTipBase), palette.inverse_surface);
    }

    #[test]
    fn inactive_group_matches_active() {
        let palette = palette();

        assert_eq!(
            QtPalette::new(&palette, QtColorGroup::Active),
            QtPalette::new(&palette, QtColorGroup::Inactive)
        );
    }

    #[test]
    fn disabled_group_neutralizes_foregrounds() {
        let palette = palette();
        let disabled = QtPalette::new(&palette, QtColorGroup::Disabled);

        assert_eq!(disabled.color(QtColorRole::Text), palette.outline);
        assert_eq!(disabled.color(QtColorRole::Link), palette.outline_variant);
        assert_eq!(
            disabled.color(QtColorRole::Window),
            palette.surface,
            "background colors must stay stable when disabled"
        );
    }

    #[test]
    fn scheme_list_has_one_color_per_role() {
        let palette = palette();
        let list = QtPalette::new(&palette, QtColorGroup::Active).to_scheme_list();
        let colors: Vec<&str> = list.split(", ").collect();

        assert_eq!(colors.len(), QT_COLOR_ROLE_COUNT);
        assert!(colors.iter().all(|color| color.starts_with('#')
            && color.len() == 9
            && color[1..].chars().all(|c| c.is_ascii_hexdigit())));
        assert!(
            colors[QtColorRole::PlaceholderText as usize].starts_with("#80"),
            "placeholder text must keep Qt's translucent convention"
        );
    }

    #[test]
    fn kde_triplets_are_decimal_rgb() {
        let palette = palette();
        let qt = QtPalette::new(&palette, QtColorGroup::Active);

        assert_eq!(
            qt.to_kde_rgb(QtColorRole::Window),
            format_rgb(palette.surface)
        );
        assert_eq!(
            qt.to_kde_rgb(QtColorRole::Highlight),
            format_rgb(palette.primary)
        );
    }
}
