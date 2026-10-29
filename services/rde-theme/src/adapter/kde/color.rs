//! # KDE Color Mapping
//!
//! Translates Material 3 roles into the grouped `kdeglobals` entries and the
//! KWin window-decoration group, keeping each slot on the role that matches its
//! KDE meaning.

use crate::domain::resolved::{Color, ColorRoles};

/// Formats a [`Color`] into decimal RGB `r,g,b` for KDE configurations.
pub(crate) fn to_kde_rgb(color: &Color) -> String {
    let clean = color.as_str().trim_start_matches('#');
    if let Ok(val) = u32::from_str_radix(clean, 16) {
        let r = (val >> 16) & 0xFF;
        let g = (val >> 8) & 0xFF;
        let b = val & 0xFF;
        format!("{r},{g},{b}")
    } else {
        "0,0,0".to_string()
    }
}

/// One configuration entry the service owns.
pub(crate) struct OwnedEntry {
    /// Section the entry belongs to.
    pub(crate) section: &'static str,

    /// Key inside that section.
    pub(crate) key: &'static str,

    /// Decimal RGB value written for the key.
    pub(crate) value: String,
}

/// Complete set of colors one KDE color group carries.
///
/// KDE applications read every key of the group they use; leaving a key out
/// falls back to Breeze's default, which is what made the generated palette
/// look partially themed (unreadable inactive text, blue focus rings, and
/// black tooltips).
///
/// Slot semantics:
/// - `active` is the default on-surface text: an active row is a row with
///   focus, not a hyperlink, so it must not use the accent.
/// - `neutral` is the warning/modified tone (unsaved changes), which the
///   tertiary family provides because Material has no dedicated warning role.
/// - `positive` is the default on-surface text: Material has no success role,
///   so a success message is written like normal text instead of borrowing an
///   accent and rendering red on a tertiary-red scheme.
///
/// Per-section backgrounds form an elevation ladder:
/// `Window = surface`, `View = surface_container_lowest`,
/// `Button = surface_container_high`, `Header = surface_container`,
/// `Complementary = surface_container_low`, `Selection = primary`,
/// `Tooltip = inverse_surface`. Button sits above Header so a button on a
/// header stands out, and Complementary sits below Header so panels recess.
pub(crate) struct ColorGroup<'a> {
    /// Base background of the group.
    background: &'a Color,

    /// Alternate background used for alternating rows.
    alternate: &'a Color,

    /// Default text and icon color.
    foreground: &'a Color,

    /// Disabled or unfocused text and icons.
    inactive: &'a Color,

    /// Text of the currently active item.
    active: &'a Color,

    /// Hyperlink text.
    link: &'a Color,

    /// Already visited hyperlink text.
    visited: &'a Color,

    /// Destructive or failed-state text.
    negative: &'a Color,

    /// Warning or modified-state text.
    neutral: &'a Color,

    /// Success or insertion-state text.
    positive: &'a Color,

    /// Focus ring and keyboard focus decoration.
    focus: &'a Color,

    /// Hover decoration.
    hover: &'a Color,
}

impl ColorGroup<'_> {
    /// Expands the group into the twelve keys KDE reads.
    fn entries(&self, section: &'static str) -> Vec<OwnedEntry> {
        [
            ("BackgroundNormal", self.background),
            ("BackgroundAlternate", self.alternate),
            ("ForegroundNormal", self.foreground),
            ("ForegroundInactive", self.inactive),
            ("ForegroundActive", self.active),
            ("ForegroundLink", self.link),
            ("ForegroundVisited", self.visited),
            ("ForegroundNegative", self.negative),
            ("ForegroundNeutral", self.neutral),
            ("ForegroundPositive", self.positive),
            ("DecorationFocus", self.focus),
            ("DecorationHover", self.hover),
        ]
        .into_iter()
        .map(|(key, color)| OwnedEntry {
            section,
            key,
            value: to_kde_rgb(color),
        })
        .collect()
    }
}

/// Builds a neutral group: surfaces for the background, on-surface text, and
/// the accent family for focus, links, and hover decoration.
///
/// `active` and `positive` read `on_surface` and `neutral` reads `tertiary`,
/// so state text does not masquerade as a link.
fn neutral_group<'a>(
    colors: &'a ColorRoles,
    background: &'a Color,
    alternate: &'a Color,
) -> ColorGroup<'a> {
    ColorGroup {
        background,
        alternate,
        foreground: &colors.on_surface,
        inactive: &colors.on_surface_variant,
        active: &colors.on_surface,
        link: &colors.primary,
        visited: &colors.tertiary,
        negative: &colors.error,
        neutral: &colors.tertiary,
        positive: &colors.on_surface,
        focus: &colors.primary,
        hover: &colors.primary,
    }
}

/// Builds the selection group, where the accent itself is the background and
/// every text key uses the on-accent color so selected rows stay readable.
fn selection_group(colors: &ColorRoles) -> ColorGroup<'_> {
    ColorGroup {
        background: &colors.primary,
        alternate: &colors.primary,
        foreground: &colors.on_primary,
        inactive: &colors.on_primary,
        active: &colors.on_primary,
        link: &colors.on_primary,
        visited: &colors.on_primary,
        negative: &colors.on_primary,
        neutral: &colors.on_primary,
        positive: &colors.on_primary,
        focus: &colors.on_primary,
        hover: &colors.on_primary,
    }
}

/// Builds the tooltip group from the inverse surface, matching Material 3's
/// inverted tooltip treatment and keeping its text readable in both modes.
fn tooltip_group(colors: &ColorRoles) -> ColorGroup<'_> {
    ColorGroup {
        background: &colors.inverse_surface,
        alternate: &colors.inverse_surface,
        foreground: &colors.inverse_on_surface,
        inactive: &colors.inverse_on_surface,
        active: &colors.inverse_primary,
        link: &colors.inverse_primary,
        visited: &colors.inverse_on_surface,
        negative: &colors.inverse_on_surface,
        neutral: &colors.inverse_on_surface,
        positive: &colors.inverse_on_surface,
        focus: &colors.inverse_primary,
        hover: &colors.inverse_primary,
    }
}

/// Builds the `[WM]` group KWin reads for its titlebars.
///
/// Window decoration keys are lower-case in KDE configuration files, unlike the
/// `Colors:*` groups.
fn wm_entries(colors: &ColorRoles) -> Vec<OwnedEntry> {
    [
        ("activeBackground", &colors.surface_container),
        ("activeForeground", &colors.on_surface),
        ("activeBlend", &colors.surface_container),
        ("inactiveBackground", &colors.surface_container_low),
        ("inactiveForeground", &colors.on_surface_variant),
        ("inactiveBlend", &colors.surface_container_low),
    ]
    .into_iter()
    .map(|(key, color)| OwnedEntry {
        section: "WM",
        key,
        value: to_kde_rgb(color),
    })
    .collect()
}

/// Builds the entries the service writes into `kdeglobals` and the color scheme.
///
/// The scheme identity is deliberately not part of these entries: writing
/// `[General] ColorScheme` into `kdeglobals` would make
/// `plasma-apply-colorscheme` treat the new scheme as already current and skip
/// applying it. The apply tool owns that key; only the standalone `.colors`
/// file names itself (see [`super::scheme::render_color_scheme`]).
pub(crate) fn owned_entries(colors: &ColorRoles) -> Vec<OwnedEntry> {
    let mut entries = Vec::new();

    // Step 1: The window sits on the plain surface; alternating rows use the
    // low container tier so they stay visible without looking striped.
    entries.extend(
        neutral_group(colors, &colors.surface, &colors.surface_container_low)
            .entries("Colors:Window"),
    );

    // Views (item views, text fields, and lists) sit on the lowest surface tier
    // so editable areas read as distinct from the window chrome.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container_lowest,
            &colors.surface_container_low,
        )
        .entries("Colors:View"),
    );

    // Step 2: Buttons sit one tier above the header they are usually drawn on,
    // so a button on a title bar or toolbar still stands out.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container_high,
            &colors.surface_container_highest,
        )
        .entries("Colors:Button"),
    );

    // Step 3: Selected rows and text fields use the accent family.
    entries.extend(selection_group(colors).entries("Colors:Selection"));

    // Step 4: Tooltips use the inverse surface, like Material 3 tooltips.
    entries.extend(tooltip_group(colors).entries("Colors:Tooltip"));

    // Step 5: Menu and title bars use the container tier so they separate from
    // the window background.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container,
            &colors.surface_container_high,
        )
        .entries("Colors:Header"),
    );

    // Step 6: Complementary panels stay in the neutral family, one tier below
    // the header, so Plasma's side panels recess instead of competing with the
    // title bar while never flipping to the accent color.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container_low,
            &colors.surface_container_lowest,
        )
        .entries("Colors:Complementary"),
    );

    // Step 7: KWin's window decoration group.
    entries.extend(wm_entries(colors));

    // Step 8: Plasma's accent color. `ColorScheme` stays untouched here; the
    // apply tool sets it when the scheme is actually applied.
    entries.push(OwnedEntry {
        section: "General",
        key: "AccentColor",
        value: to_kde_rgb(&colors.primary),
    });

    entries
}
