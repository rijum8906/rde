//! # KDE Color Integration
//!
//! Generates the `kdeglobals` color groups, the window decoration group, and
//! the generation-scoped Plasma color scheme from semantic [`ColorRoles`].

use std::{
    collections::HashSet,
    path::{Path, PathBuf},
};

use crate::{
    backend::{Adapter, BackendError, BackendOutput},
    domain::{
        ThemeId, VariantId,
        resolved::{Color, ColorRoles, ResolvedTheme},
    },
};

pub const KDE_ADAPTER_NAME: &str = "kde";
pub const KDE_GLOBALS_PATH_KEY: &str = "kde_globals";
pub const KDE_COLOR_SCHEME_PATH_KEY: &str = "kde_color_scheme";

/// Directory inside the XDG data home where Plasma looks up color schemes.
pub const KDE_COLOR_SCHEMES_DIR: &str = "color-schemes";

/// File extension of a Plasma color scheme.
pub const KDE_COLOR_SCHEME_EXTENSION: &str = "colors";

/// Name of the KDE color scheme the service installs and applies.
///
/// This is only the placeholder used before the first publication; every
/// publication replaces it with the generation-scoped name built by
/// [`crate::backend::unique_theme_name`].
pub const KDE_COLOR_SCHEME_NAME: &str = "RdeM3";

/// Sections of `kdeglobals` the service owns, in write order.
///
/// `Colors:Header` colors menu and title bars, `Colors:Complementary` covers
/// Plasma's complementary panels, and `WM` carries the window decoration colors
/// KWin reads. `General` always comes last so the scheme identity lands after
/// the color groups.
const OWNED_SECTIONS: [&str; 9] = [
    "Colors:Window",
    "Colors:View",
    "Colors:Button",
    "Colors:Selection",
    "Colors:Tooltip",
    "Colors:Header",
    "Colors:Complementary",
    "WM",
    "General",
];

/// Formats a [`Color`] into decimal RGB `r,g,b` for KDE configurations.
fn to_kde_rgb(color: &Color) -> String {
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
struct OwnedEntry {
    section: &'static str,
    key: &'static str,
    value: String,
}

/// Complete set of colors one KDE color group carries.
///
/// KDE applications read every key of the group they use; leaving a key out
/// falls back to Breeze's default, which is what made the generated palette
/// look partially themed (unreadable inactive text, blue focus rings, and
/// black tooltips).
struct ColorGroup<'a> {
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
/// the accent family for focus, links, and active items.
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
        active: &colors.primary,
        link: &colors.primary,
        visited: &colors.tertiary,
        negative: &colors.error,
        neutral: &colors.secondary,
        positive: &colors.tertiary,
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
/// file names itself (see [`render_color_scheme`]).
fn owned_entries(colors: &ColorRoles) -> Vec<OwnedEntry> {
    let mut entries = Vec::new();

    // Step 1: Windows and views share the neutral surface; alternating rows use
    // the low container tier so they stay visible without looking striped.
    entries.extend(
        neutral_group(colors, &colors.surface, &colors.surface_container_low)
            .entries("Colors:Window"),
    );

    // Views (item views, text fields, and lists) sit on the lowest surface so
    // editable areas read as distinct from the window chrome.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container_lowest,
            &colors.surface_container_low,
        )
        .entries("Colors:View"),
    );

    // Step 2: Buttons sit one container tier up, with a stronger alternate.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container,
            &colors.surface_container_high,
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
    // headers, so Plasma's side panels do not flip to the accent color.
    entries.extend(
        neutral_group(
            colors,
            &colors.surface_container_low,
            &colors.surface_container,
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

/// Generates a complete `kdeglobals` document from [`ColorRoles`].
///
/// # Parameters
/// - `colors`: the resolved Material 3 roles to translate
#[must_use]
pub fn render_kdeglobals(colors: &ColorRoles) -> String {
    let entries = owned_entries(colors);
    let mut out = String::from("; Generated by rde-theme; do not edit.\n");

    for section in OWNED_SECTIONS {
        out.push_str(&format!("\n[{section}]\n"));
        for entry in entries.iter().filter(|entry| entry.section == section) {
            out.push_str(&format!("{}={}\n", entry.key, entry.value));
        }
    }

    out
}

/// Builds the unique color scheme name for one publication generation.
///
/// The name is shared with every other themed surface (see
/// [`crate::backend::unique_theme_name`]), so a regenerated palette installs
/// under a **new** name instead of overwriting the scheme Plasma currently
/// reads. That is what makes the scheme follow a regeneration that only changes
/// colors.
#[must_use]
pub fn kde_color_scheme_name(
    theme_id: &ThemeId,
    variant_id: &VariantId,
    generation: u32,
) -> String {
    crate::backend::unique_theme_name(theme_id, variant_id, generation)
}

/// Generates the `RdeM3` Plasma color scheme that `plasma-apply-colorscheme` reads.
///
/// # Parameters
/// - `color_roles`: the resolved Material 3 roles to translate
/// - `kde_color_scheme_name`: generation-scoped name of the installed scheme
#[must_use]
pub fn render_color_scheme(color_roles: &ColorRoles, kde_color_scheme_name: &str) -> String {
    let entries = owned_entries(color_roles);
    let mut out = String::from("; Generated by rde-theme; do not edit.\n");

    // Step 1: Identity of the scheme, which Plasma shows in System Settings.
    // Only the standalone scheme names itself; `kdeglobals` must not pre-select
    // it, or `plasma-apply-colorscheme` treats it as already applied and skips
    // the refresh (`ColorScheme` and `ColorSchemeHash` are written by the tool).
    out.push_str("\n[General]\n");
    out.push_str(&format!("Name={kde_color_scheme_name}\n"));
    out.push_str(&format!("ColorScheme={kde_color_scheme_name}\n"));
    for entry in entries.iter().filter(|entry| entry.section == "General") {
        out.push_str(&format!("{}={}\n", entry.key, entry.value));
    }
    out.push_str("shadeSortColumn=true\n");

    // Step 2: Every color group the scheme overrides.
    for section in OWNED_SECTIONS
        .iter()
        .filter(|section| **section != "General")
    {
        out.push_str(&format!("\n[{section}]\n"));
        for entry in entries.iter().filter(|entry| entry.section == *section) {
            out.push_str(&format!("{}={}\n", entry.key, entry.value));
        }
    }

    out
}

/// Replaces the service-owned keys in an existing `kdeglobals` document.
///
/// Everything the service does not own (styles, fonts, icons, comments, and
/// unrelated keys) is preserved, so updating the theme never resets the user's
/// KDE configuration. Missing sections and keys are appended.
///
/// # Parameters
/// - `existing`: current `kdeglobals` content, usually read from disk
/// - `colors`: the resolved Material 3 roles to translate
#[must_use]
pub fn merge_kdeglobals(existing: &str, colors: &ColorRoles) -> String {
    let entries = owned_entries(colors);
    let mut lines: Vec<String> = existing.lines().map(str::to_string).collect();
    let mut written: HashSet<(&'static str, &'static str)> = HashSet::new();

    // Step 1: Replace values that already exist inside their owned section.
    for span in section_spans(&lines) {
        if !OWNED_SECTIONS.contains(&span.header.as_str()) {
            continue;
        }
        for line in lines
            .iter_mut()
            .take(span.end_index)
            .skip(span.header_index + 1)
        {
            let trimmed = line.trim().to_string();
            if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('#') {
                continue;
            }
            let Some((key, _)) = trimmed.split_once('=') else {
                continue;
            };
            let key = key.trim();
            if let Some(entry) = entries
                .iter()
                .find(|entry| entry.section == span.header.as_str() && entry.key == key)
            {
                *line = format!("{}={}", entry.key, entry.value);
                written.insert((entry.section, entry.key));
            }
        }
    }

    // Step 2: Insert missing keys into sections that already exist. Spans are
    // recomputed after every insertion because indices shift.
    loop {
        let spans = section_spans(&lines);
        let missing = entries.iter().find(|entry| {
            !written.contains(&(entry.section, entry.key))
                && spans.iter().any(|span| span.header == entry.section)
        });

        let Some(entry) = missing else {
            break;
        };
        let span = spans
            .iter()
            .find(|span| span.header == entry.section)
            .map(|span| span.end_index)
            .unwrap_or(lines.len());
        lines.insert(span, format!("{}={}", entry.key, entry.value));
        written.insert((entry.section, entry.key));
    }

    // Step 3: Append whole sections the document did not have yet.
    for section in OWNED_SECTIONS {
        if lines
            .iter()
            .any(|line| line.trim() == format!("[{section}]"))
        {
            continue;
        }
        if lines.last().is_some_and(|line| !line.trim().is_empty()) {
            lines.push(String::new());
        }
        lines.push(format!("[{section}]"));
        for entry in entries.iter().filter(|entry| entry.section == section) {
            lines.push(format!("{}={}", entry.key, entry.value));
        }
    }

    let mut out = lines.join("\n");
    out.push('\n');
    out
}

/// Facts about one `[Section]` in an INI document.
struct SectionSpan {
    /// Section name without the brackets.
    header: String,

    /// Index of the `[Section]` line.
    header_index: usize,

    /// Index of the next section header, or the line count for the last section.
    end_index: usize,
}

/// Locates every section in an INI document.
fn section_spans(lines: &[String]) -> Vec<SectionSpan> {
    let mut spans: Vec<SectionSpan> = Vec::new();

    for (index, line) in lines.iter().enumerate() {
        let trimmed = line.trim();
        if trimmed.len() > 2 && trimmed.starts_with('[') && trimmed.ends_with(']') {
            spans.push(SectionSpan {
                header: trimmed[1..trimmed.len() - 1].to_string(),
                header_index: index,
                end_index: lines.len(),
            });
        }
    }

    for index in 0..spans.len().saturating_sub(1) {
        spans[index].end_index = spans[index + 1].header_index;
    }

    spans
}

/// Backend adapter emitting the KDE color scheme and config fragments.
#[derive(Debug, Clone)]
pub struct KdeAdapter {
    config_home: PathBuf,
    data_home: PathBuf,
    kde_color_scheme_name: String,
}

impl KdeAdapter {
    /// Constructs a new [`KdeAdapter`].
    ///
    /// # Parameters
    /// - `config_home`: XDG config home (`~/.config` by default). KDE applications
    ///   read colors from `kdeglobals` here.
    /// - `data_home`: XDG data home (`~/.local/share` by default). The scheme is
    ///   installed under `color-schemes/`, where Plasma looks it up.
    #[must_use]
    pub fn new(config_home: PathBuf, data_home: PathBuf) -> Self {
        Self {
            config_home,
            data_home,
            kde_color_scheme_name: KDE_COLOR_SCHEME_NAME.to_string(),
        }
    }

    /// Path of the `kdeglobals` file KDE applications read.
    #[must_use]
    pub fn kdeglobals_path(&self) -> PathBuf {
        self.config_home.join("kdeglobals")
    }

    /// Path of the color scheme installed for Plasma.
    #[must_use]
    pub fn color_scheme_path(&self) -> PathBuf {
        color_scheme_path(&self.data_home, self.kde_color_scheme_name.clone())
    }

    /// Lists the color schemes generated for the same theme and variant by an
    /// earlier publication generation.
    ///
    /// # Returns
    ///
    /// Absolute paths of superseded `<theme>-<variant>-v<generation>.colors`
    /// files. The scheme of the current generation, schemes of other variants,
    /// and every scheme the user installed are excluded, so the caller can
    /// delete the result unconditionally.
    #[must_use]
    pub fn stale_color_schemes(&self) -> Vec<PathBuf> {
        // Step 1: Split the generation off the current name. `rsplit_once` takes
        // the last `-v`, so theme and variant ids containing `-v` stay intact.
        let Some((prefix, _)) = self.kde_color_scheme_name.rsplit_once("-v") else {
            return Vec::new();
        };
        let generated = format!("{prefix}-v");
        let current = self.color_scheme_path();

        // Step 2: A missing directory simply means nothing was generated yet.
        let Ok(entries) = std::fs::read_dir(color_schemes_dir(&self.data_home)) else {
            return Vec::new();
        };

        // Step 3: Keep only files this service generated for an older generation.
        entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                if path == &current
                    || path.extension().and_then(|ext| ext.to_str()) != Some("colors")
                {
                    return false;
                }
                let Some(stem) = path.file_stem().and_then(|stem| stem.to_str()) else {
                    return false;
                };
                stem.strip_prefix(&generated).is_some_and(|generation| {
                    !generation.is_empty() && generation.bytes().all(|byte| byte.is_ascii_digit())
                })
            })
            .collect()
    }
}

pub fn kdeglobals_path(config_home: impl AsRef<Path>) -> PathBuf {
    config_home.as_ref().to_path_buf().join("kdeglobals")
}

/// Directory Plasma searches for installed color schemes.
pub fn color_schemes_dir(data_home: impl AsRef<Path>) -> PathBuf {
    data_home.as_ref().to_path_buf().join(KDE_COLOR_SCHEMES_DIR)
}

pub fn color_scheme_path(data_home: impl AsRef<Path>, kde_color_scheme_name: String) -> PathBuf {
    color_schemes_dir(data_home).join(format!(
        "{kde_color_scheme_name}.{KDE_COLOR_SCHEME_EXTENSION}"
    ))
}

impl Adapter for KdeAdapter {
    fn name(&self) -> &'static str {
        KDE_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        // Step 1: Merge into the real kdeglobals so the user's other settings
        // survive a theme change. A missing or empty file is generated whole.
        let globals_path = self.kdeglobals_path();
        let existing = read_optional(&globals_path);
        let globals = if existing.trim().is_empty() {
            render_kdeglobals(&theme.colors)
        } else {
            merge_kdeglobals(&existing, &theme.colors)
        };

        // Step 2: Install the scheme Plasma applies at startup and on change.
        // The name carries the generation, so the desktop can tell a regenerated
        // palette apart from the one it already applied.
        let scheme = render_color_scheme(&theme.colors, &self.kde_color_scheme_name);

        // Step 3: Report the scheme of the previous generation for deletion. The
        // caller removes it only after the new scheme is durable on disk.
        let removals = self.stale_color_schemes();

        Ok(BackendOutput {
            files: vec![
                (globals_path, globals.into_bytes()),
                (self.color_scheme_path(), scheme.into_bytes()),
            ],
            env: Vec::new(),
            removals,
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.kde_color_scheme_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.kde_color_scheme_name.clone()
    }
}

/// Reads a file, treating "missing" and "unreadable" as empty content.
fn read_optional(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::backend::material::compute_color_roles;
    use crate::domain::{ColorSeeds, ContrastLevel, ThemeMode};

    static KDE_COLOR_SCHEM_NAME: &str = "RdeM3";

    /// Builds a deterministic palette for the assertions below.
    fn roles() -> ColorRoles {
        compute_color_roles(
            &ColorSeeds::uniform(&Color::new("#6750a4").unwrap()),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        )
    }

    /// Builds the published payload the adapter renders.
    fn theme() -> ResolvedTheme {
        ResolvedTheme {
            schema_version: 1,
            theme_id: crate::domain::ThemeId::builtin_dynamic(),
            variant: crate::domain::VariantId::new("dark").unwrap(),
            kind: crate::domain::VariantKind::Dynamic,
            colors: roles(),
            typography: crate::domain::Typography::default(),
            shape: crate::domain::Shape::default(),
            motion: crate::domain::Motion::default(),
        }
    }

    /// Returns the block of one section, without its header.
    fn section<'a>(content: &'a str, header: &str) -> &'a str {
        let start = content
            .find(&format!("[{header}]"))
            .unwrap_or_else(|| panic!("missing section {header}: {content}"));
        let rest = &content[start + header.len() + 2..];
        let end = rest.find("\n[").unwrap_or(rest.len());
        &rest[..end]
    }

    #[test]
    fn renders_every_owned_group() {
        let content = render_kdeglobals(&roles());

        for section in OWNED_SECTIONS {
            assert!(
                content.contains(&format!("[{section}]")),
                "missing section {section}: {content}"
            );
        }
        for key in [
            "BackgroundNormal",
            "BackgroundAlternate",
            "ForegroundNormal",
            "ForegroundInactive",
            "ForegroundActive",
            "ForegroundLink",
            "ForegroundVisited",
            "ForegroundNegative",
            "ForegroundNeutral",
            "ForegroundPositive",
            "DecorationFocus",
            "DecorationHover",
        ] {
            assert!(
                content.contains(&format!("\n{key}=")),
                "missing key {key}: {content}"
            );
        }
        assert!(content.contains("AccentColor="), "{content}");
        // `plasma-apply-colorscheme` skips a scheme that is already selected, so
        // the document must leave `ColorScheme` to the apply tool.
        assert!(
            !content.contains("ColorScheme="),
            "kdeglobals must not pre-select the generated scheme: {content}"
        );
    }

    #[test]
    fn maps_surfaces_and_accents_onto_the_groups() {
        let colors = roles();
        let content = render_color_scheme(&colors, KDE_COLOR_SCHEM_NAME);

        // Window text follows the surface roles, and focus/hover carry the
        // accent instead of Breeze's blue.
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
    fn color_scheme_carries_its_identity() {
        let content = render_color_scheme(&roles(), KDE_COLOR_SCHEM_NAME);

        assert!(content.contains("Name=RdeM3"), "{content}");
        assert!(content.contains("ColorScheme=RdeM3"), "{content}");
        assert!(content.contains("[Colors:Selection]"), "{content}");
    }

    #[test]
    fn merge_preserves_unrelated_settings_and_comments() {
        let existing = "; my comment\n[General]\nAccentColor=1,2,3\nColorScheme=BreezeDark\n\
            Font=Noto Sans\n\n[Colors:Window]\nBackgroundNormal=9,9,9\n\
            InactiveText=8,8,8\n\n[KDE]\nLookAndFeelPackage=org.kde.breeze\n";

        let merged = merge_kdeglobals(existing, &roles());

        assert!(merged.contains("; my comment"), "{merged}");
        assert!(merged.contains("Font=Noto Sans"), "{merged}");
        assert!(merged.contains("InactiveText=8,8,8"), "{merged}");
        assert!(
            merged.contains("LookAndFeelPackage=org.kde.breeze"),
            "{merged}"
        );
        assert!(!merged.contains("AccentColor=1,2,3"), "{merged}");
        assert!(!merged.contains("BackgroundNormal=9,9,9"), "{merged}");
        // The scheme selection belongs to `plasma-apply-colorscheme`; the merge
        // must neither overwrite it nor add one on a non-KDE session.
        assert!(merged.contains("ColorScheme=BreezeDark"), "{merged}");
    }

    #[test]
    fn merge_appends_missing_sections_without_duplicates() {
        let merged = merge_kdeglobals("[General]\nAccentColor=1,2,3\n", &roles());

        for section in OWNED_SECTIONS {
            let header = format!("[{section}]");
            assert_eq!(
                merged.matches(&header).count(),
                1,
                "duplicate {header}: {merged}"
            );
        }
    }

    #[test]
    fn emitter_targets_the_paths_kde_reads() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let data_home = temp.path().join("data");
        std::fs::create_dir_all(&config_home).unwrap();

        // An existing kdeglobals with a user-owned key must survive.
        std::fs::write(
            config_home.join("kdeglobals"),
            "[KDE]\nLookAndFeelPackage=org.kde.breeze\n",
        )
        .unwrap();

        let resolved_theme = theme();
        let scheme_name =
            kde_color_scheme_name(&resolved_theme.theme_id, &resolved_theme.variant, 3);
        let mut emitter = KdeAdapter::new(config_home.clone(), data_home.clone());

        // The service names the scheme after the generation before rendering it.
        emitter.set_unique_theme_name(scheme_name.clone());
        let output = emitter.render(&resolved_theme).unwrap();

        let paths: Vec<_> = output.files.iter().map(|(path, _)| path.clone()).collect();
        assert!(paths.contains(&config_home.join("kdeglobals")), "{paths:?}");
        assert_eq!(scheme_name, "rde-dynamic-dark-v3");
        assert!(
            paths.contains(
                &data_home
                    .join("color-schemes")
                    .join(format!("{scheme_name}.colors"))
            ),
            "{paths:?}"
        );

        let globals = output
            .files
            .iter()
            .find(|(path, _)| path.ends_with("kdeglobals"))
            .map(|(_, bytes)| String::from_utf8_lossy(bytes).into_owned())
            .unwrap();
        assert!(
            globals.contains("LookAndFeelPackage=org.kde.breeze"),
            "{globals}"
        );
        assert!(globals.contains("[Colors:Window]"), "{globals}");
        assert!(
            !globals.contains("ColorScheme="),
            "the apply tool owns the scheme selection: {globals}"
        );

        // Writing the files exactly as the application layer does must leave a
        // merged kdeglobals and a discoverable scheme at the KDE paths.
        for (path, bytes) in &output.files {
            crate::fs::write_atomic(path, bytes).unwrap();
        }
        let on_disk = std::fs::read_to_string(config_home.join("kdeglobals")).unwrap();
        assert!(on_disk.contains("[Colors:Window]"), "{on_disk}");
        let scheme = std::fs::read_to_string(
            data_home
                .join("color-schemes")
                .join(format!("{scheme_name}.colors")),
        )
        .unwrap();
        assert!(scheme.contains("Name=rde-dynamic-dark-v3"), "{scheme}");
    }

    #[test]
    fn render_supersedes_only_the_schemes_of_the_same_variant() {
        let temp = tempfile::tempdir().unwrap();
        let data_home = temp.path().join("data");
        let schemes = color_schemes_dir(&data_home);
        std::fs::create_dir_all(&schemes).unwrap();

        // A scheme generated for an earlier generation, a scheme the user
        // installed, and the scheme of the other variant on disk.
        std::fs::write(schemes.join("rde-dynamic-dark-v6.colors"), "stale").unwrap();
        std::fs::write(schemes.join("Breeze.colors"), "user installed").unwrap();
        std::fs::write(schemes.join("rde-dynamic-light-v6.colors"), "other").unwrap();

        let mut emitter = KdeAdapter::new(temp.path().join("config"), data_home);
        emitter.set_unique_theme_name("rde-dynamic-dark-v7".to_string());
        let output = emitter.render(&theme()).unwrap();

        // Only the superseded scheme of the same theme and variant is reported.
        assert_eq!(
            output.removals,
            vec![schemes.join("rde-dynamic-dark-v6.colors")]
        );
        assert!(
            output
                .files
                .iter()
                .any(|(path, _)| path.ends_with("rde-dynamic-dark-v7.colors")),
            "{output:?}"
        );
    }
}
