//! # Qt Platform Theme Integration
//!
//! Writes Material 3 palettes for qt5ct and qt6ct and selects them in each
//! tool's configuration when the platform theme is installed.

use std::path::{Path, PathBuf};

use crate::{
    backend::{Adapter, BackendError, BackendOutput},
    domain::resolved::{Color, ColorRoles, ResolvedTheme},
};

pub const QT_ADAPTER_NAME: &str = "qt";

/// Name of the palette the service installs before the first publication.
///
/// Every publication replaces it with the generation-scoped name built by
/// [`crate::backend::unique_theme_name`], so a regenerated palette lands at a
/// new path and qt5ct/qt6ct reload it instead of keeping the old one.
pub const QT_PALETTE_NAME: &str = "RdeM3";

/// Subdirectory of a qt5ct/qt6ct config directory that holds palettes.
const QTCT_COLORS_DIR: &str = "colors";

/// File extension of both qt5ct/qt6ct palettes and their config files.
const QTCT_EXTENSION: &str = "conf";

/// Section of a qt5ct/qt6ct palette file.
const QTCT_COLOR_SCHEME_SECTION: &str = "ColorScheme";

/// Section of a qt5ct/qt6ct config file that selects the palette.
const QTCT_CONFIG_SECTION: &str = "Appearance";

/// One of the two supported Qt configuration tools.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum QtTool {
    Qt5,
    Qt6,
}

impl QtTool {
    /// Both tools, in write order.
    const ALL: [QtTool; 2] = [QtTool::Qt5, QtTool::Qt6];

    /// Directory name below the XDG config home, which doubles as the config
    /// file stem (`qt5ct/qt5ct.conf`).
    fn name(self) -> &'static str {
        match self {
            QtTool::Qt5 => "qt5ct",
            QtTool::Qt6 => "qt6ct",
        }
    }
}

/// Adapter emitting qt5ct and qt6ct palettes and their tool configs.
///
/// A tool is only touched when it is installed: either its platform theme
/// plugin was detected or its config directory already exists, which means the
/// user has run it at least once.
#[derive(Debug, Clone)]
pub struct QtAdapter {
    config_home: PathBuf,
    palette_name: String,
    qt5ct: bool,
    qt6ct: bool,
}

impl QtAdapter {
    /// Constructs the adapter and detects the installed Qt configuration tools.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home (`~/.config` by default)
    #[must_use]
    pub fn new(config_home: PathBuf) -> Self {
        // Step 1: The platform theme plugin proves the tool exists.
        let (qt5ct_plugin, qt6ct_plugin) = crate::backend::detect::qtct_plugins();

        // Step 2: An existing config directory also counts. It covers Qt builds
        // whose plugin lives outside the probed paths and tools that were run
        // with a different Qt version.
        let qt5ct = qt5ct_plugin || config_home.join(QtTool::Qt5.name()).is_dir();
        let qt6ct = qt6ct_plugin || config_home.join(QtTool::Qt6.name()).is_dir();

        Self::with_targets(config_home, qt5ct, qt6ct)
    }

    /// Constructs the adapter with explicit tool availability.
    ///
    /// Used by [`QtAdapter::new`] after detection and by tests that need a
    /// deterministic target set.
    ///
    /// # Parameters
    /// - `config_home`: XDG config home
    /// - `qt5ct`: whether qt5ct is installed
    /// - `qt6ct`: whether qt6ct is installed
    #[must_use]
    pub fn with_targets(config_home: PathBuf, qt5ct: bool, qt6ct: bool) -> Self {
        Self {
            config_home,
            palette_name: QT_PALETTE_NAME.to_string(),
            qt5ct,
            qt6ct,
        }
    }

    /// Whether the adapter should write for [tool].
    fn is_enabled(&self, tool: QtTool) -> bool {
        match tool {
            QtTool::Qt5 => self.qt5ct,
            QtTool::Qt6 => self.qt6ct,
        }
    }

    /// Config directory of [tool] (`~/.config/qt5ct` or `~/.config/qt6ct`).
    fn tool_dir(&self, tool: QtTool) -> PathBuf {
        self.config_home.join(tool.name())
    }

    /// Config file of [tool] (`qt5ct.conf` or `qt6ct.conf`).
    fn config_path(&self, tool: QtTool) -> PathBuf {
        self.tool_dir(tool)
            .join(format!("{}.{QTCT_EXTENSION}", tool.name()))
    }

    /// Palette file installed for [tool] in the current generation.
    fn palette_path(&self, tool: QtTool) -> PathBuf {
        self.tool_dir(tool)
            .join(QTCT_COLORS_DIR)
            .join(format!("{}.{QTCT_EXTENSION}", self.palette_name))
    }

    /// Lists palettes generated for the same theme and variant by an earlier
    /// publication generation.
    ///
    /// # Returns
    /// Absolute paths of superseded `<theme>-<variant>-v<generation>.conf`
    /// files. Palettes the user installed and the palette of the current
    /// generation are excluded, so the caller can delete the result
    /// unconditionally.
    fn stale_palettes(&self, tool: QtTool) -> Vec<PathBuf> {
        // Step 1: Split the generation off the current name. `rsplit_once` takes
        // the last `-v`, so theme and variant ids containing `-v` stay intact.
        let Some((prefix, _)) = self.palette_name.rsplit_once("-v") else {
            return Vec::new();
        };
        let generated = format!("{prefix}-v");
        let current = self.palette_path(tool);

        // Step 2: A missing colors directory means nothing was generated yet.
        let Ok(entries) = std::fs::read_dir(self.tool_dir(tool).join(QTCT_COLORS_DIR)) else {
            return Vec::new();
        };

        // Step 3: Keep only files this service generated for an older generation.
        entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                if path == &current
                    || path.extension().and_then(|ext| ext.to_str()) != Some(QTCT_EXTENSION)
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

impl Adapter for QtAdapter {
    fn name(&self) -> &'static str {
        QT_ADAPTER_NAME
    }

    fn render(&self, theme: &ResolvedTheme) -> Result<BackendOutput, BackendError> {
        let mut files = Vec::new();
        let mut removals = Vec::new();
        let mut env: Vec<(String, String)> = Vec::new();

        for tool in QtTool::ALL {
            // Step 1: Leave tools that are not installed untouched.
            if !self.is_enabled(tool) {
                continue;
            }

            // Step 2: Install the palette under the generation-scoped name.
            let palette_path = self.palette_path(tool);
            files.push((
                palette_path.clone(),
                render_qtct_palette(&theme.colors).into_bytes(),
            ));

            // Step 3: Point the tool at it, preserving the user's other settings.
            let config_path = self.config_path(tool);
            let existing = read_optional(&config_path);
            files.push((
                config_path,
                merge_qtct_config(&existing, &palette_path).into_bytes(),
            ));

            // Step 4: Report the palettes of older generations for deletion.
            removals.extend(self.stale_palettes(tool));

            // QT_QPA_PLATFORMTHEME=qt6ct or qt5ct
            env.push(("QT_QPA_PLATFORMTHEME".into(), tool.name().into()));
        }

        Ok(BackendOutput {
            files,
            env,
            removals,
        })
    }

    fn set_unique_theme_name(&mut self, theme_name: String) {
        self.palette_name = theme_name
    }

    fn unique_theme_name(&self) -> String {
        self.palette_name.clone()
    }
}

/// Renders a qt5ct/qt6ct palette from [`ColorRoles`].
///
/// The three color groups are serialized in Qt's `QPalette::ColorRole` order,
/// including the unused `NoRole` slot and the Qt 6.6 `Accent` role, because both
/// tools index the list by role value.
fn render_qtct_palette(colors: &ColorRoles) -> String {
    let active = active_palette(colors);
    let disabled = disabled_palette(colors);

    let mut out = String::from("; Generated by rde-theme; do not edit.\n");
    out.push_str(&format!("\n[{QTCT_COLOR_SCHEME_SECTION}]\n"));
    out.push_str(&format!("active_colors={}\n", format_palette(&active)));
    // Active and inactive share colors; Qt styles resolve inactive roles from
    // the active group unless the user changes them.
    out.push_str(&format!("inactive_colors={}\n", format_palette(&active)));
    out.push_str(&format!("disabled_colors={}\n", format_palette(&disabled)));

    out
}

/// The 22 QPalette role colors of the active group, in Qt serialization order.
///
/// Role mapping rationale:
/// - `Window`/`WindowText` — the app background and its primary text.
/// - `Base`/`Text` — input fields, list views, editor backgrounds.
///   Material's `surface_container_low` (not `_lowest`) is the role
///   designed for "the surface you interact with," so it reads as a
///   field rather than a recessed void.
/// - `Button`/`ButtonText` — a filled tonal button, using Material's
///   `secondary_container`/`on_secondary_container` pair. Using `primary`
///   here would make every button a FAB; using `surface_container` would
///   make it look like a label.
/// - `Highlight`/`HighlightedText` — a selection highlight, using
///   `primary_container`/`on_primary_container` so selections are visible
///   but not overwhelming. `primary` is reserved for the Accent slot.
/// - `ToolTipBase`/`ToolTipText` — a raised surface, not an inverse one.
///   Qt tooltips are info popups, not snackbars.
/// - `Shadow` — an actual shadow, mode-aware.
/// - `Link`/`LinkVisited` — `primary` and a darkened `primary`, so a
///   visited link reads as "link, but visited" rather than a new hue.
fn active_palette(colors: &ColorRoles) -> [&Color; 22] {
    [
        &colors.on_surface,                // WindowText
        &colors.secondary_container,       // Button
        &colors.surface_container_high,    // Light
        &colors.surface_container,         // Midlight
        &colors.surface_container_lowest,  // Dark
        &colors.outline_variant,           // Mid
        &colors.on_surface,                // Text
        &colors.on_surface,                // BrightText
        &colors.on_secondary_container,    // ButtonText
        &colors.surface_container_low,     // Base
        &colors.surface,                   // Window
        &colors.shadow,                    // Shadow
        &colors.primary_container,         // Highlight
        &colors.on_primary_container,      // HighlightedText
        &colors.primary,                   // Link
        &colors.on_primary_container,      // LinkVisited
        &colors.surface_container_low,     // AlternateBase
        &colors.surface,                   // NoRole (ignored by Qt)
        &colors.surface_container_highest, // ToolTipBase
        &colors.on_surface,                // ToolTipText
        &colors.on_surface_variant,        // PlaceholderText
        &colors.primary,                   // Accent (Qt 6.6+)
    ]
}

/// The 22 QPalette role colors of the disabled group.
///
/// Surfaces stay the same as the active group (the widget is still there);
/// text roles move to `on_surface_variant` (Material's "muted text"); link
/// roles move to `outline` (the "unavailable" role). Shadow and Highlight
/// keep their active values so a disabled widget's focus ring and
/// drop shadow still read as "part of the same widget."
fn disabled_palette(colors: &ColorRoles) -> [&Color; 22] {
    [
        &colors.on_surface_variant,       // WindowText
        &colors.surface_container,        // Button
        &colors.surface_container_high,   // Light
        &colors.surface_container,        // Midlight
        &colors.surface_container_lowest, // Dark
        &colors.outline_variant,          // Mid
        &colors.on_surface_variant,       // Text
        &colors.on_surface_variant,       // BrightText
        &colors.on_surface_variant,       // ButtonText
        &colors.surface_container_low,    // Base
        &colors.surface,                  // Window
        &colors.shadow,                   // Shadow
        &colors.primary_container,        // Highlight
        &colors.on_primary_container,     // HighlightedText
        &colors.outline,                  // Link
        &colors.outline,                  // LinkVisited
        &colors.surface_container_low,    // AlternateBase
        &colors.surface,                  // NoRole (ignored by Qt)
        &colors.surface_container_high,   // ToolTipBase
        &colors.on_surface_variant,       // ToolTipText
        &colors.outline_variant,          // PlaceholderText
        &colors.primary,                  // Accent (Qt 6.6+)
    ]
}

/// Joins one group's colors as `#aarrggbb` values.
fn format_palette(palette: &[&Color]) -> String {
    palette
        .iter()
        .map(|color| qtct_color(color))
        .collect::<Vec<_>>()
        .join(", ")
}

/// Formats a [`Color`] as the opaque `#aarrggbb` value qt5ct/qt6ct expect.
fn qtct_color(color: &Color) -> String {
    format!("#ff{}", color.as_str().trim_start_matches('#'))
}

/// Updates the palette selection in a qt5ct/qt6ct config document.
///
/// Everything else (style, icons, fonts, comments) is preserved, so switching
/// palettes never resets the user's tool configuration.
fn merge_qtct_config(existing: &str, palette_path: &Path) -> String {
    let entries = [
        ("color_scheme_path", palette_path.display().to_string()),
        ("custom_palette", "true".to_string()),
    ];
    let mut lines: Vec<String> = existing.lines().map(str::to_string).collect();
    let mut written = [false; 2];

    let header = lines
        .iter()
        .position(|line| line.trim() == format!("[{QTCT_CONFIG_SECTION}]"));

    match header {
        // Step 1: Replace the owned keys inside an existing [Appearance] group.
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
        // Step 3: Append the whole group when the tool has no config yet.
        None => {
            if lines.last().is_some_and(|line| !line.trim().is_empty()) {
                lines.push(String::new());
            }
            lines.push(format!("[{QTCT_CONFIG_SECTION}]"));
            for (key, value) in entries {
                lines.push(format!("{key}={value}"));
            }
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
fn read_optional(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::backend::material::compute_color_roles;
    use crate::domain::{ColorSeeds, ContrastLevel, ThemeMode};

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

    /// Returns the comma-separated values of one group line.
    fn group_values<'a>(palette: &'a str, key: &str) -> Vec<&'a str> {
        palette
            .lines()
            .find_map(|line| line.strip_prefix(&format!("{key}=")))
            .unwrap_or_else(|| panic!("missing {key}: {palette}"))
            .split(", ")
            .collect()
    }

    #[test]
    fn writes_a_palette_and_config_for_every_installed_tool() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let mut adapter = QtAdapter::with_targets(config_home.clone(), true, true);
        adapter.set_unique_theme_name("rde-dynamic-dark-v3".to_string());

        let output = adapter.render(&theme()).unwrap();

        let palette = config_home
            .join("qt5ct")
            .join("colors")
            .join("rde-dynamic-dark-v3.conf");
        let config = config_home.join("qt5ct").join("qt5ct.conf");
        let paths: Vec<_> = output.files.iter().map(|(path, _)| path.clone()).collect();
        assert!(paths.contains(&palette), "{paths:?}");
        assert!(paths.contains(&config), "{paths:?}");
        assert!(
            paths.contains(
                &config_home
                    .join("qt6ct")
                    .join("colors")
                    .join("rde-dynamic-dark-v3.conf")
            ),
            "{paths:?}"
        );
        assert!(paths.contains(&config_home.join("qt6ct").join("qt6ct.conf")));

        let content = output
            .files
            .iter()
            .find(|(path, _)| path == &palette)
            .map(|(_, bytes)| String::from_utf8_lossy(bytes).into_owned())
            .unwrap();
        assert!(content.contains("[ColorScheme]"), "{content}");
        assert_eq!(group_values(&content, "active_colors").len(), 22);
        assert_eq!(group_values(&content, "inactive_colors").len(), 22);
        assert_eq!(group_values(&content, "disabled_colors").len(), 22);

        let config_content = output
            .files
            .iter()
            .find(|(path, _)| path == &config)
            .map(|(_, bytes)| String::from_utf8_lossy(bytes).into_owned())
            .unwrap();
        assert!(
            config_content.contains("custom_palette=true"),
            "{config_content}"
        );
        assert!(
            config_content.contains(&format!("color_scheme_path={}", palette.display())),
            "{config_content}"
        );
    }

    #[test]
    fn skips_tools_that_are_not_installed() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let mut adapter = QtAdapter::with_targets(config_home.clone(), false, true);
        adapter.set_unique_theme_name("rde-dynamic-dark-v3".to_string());

        let output = adapter.render(&theme()).unwrap();

        let paths: Vec<_> = output.files.iter().map(|(path, _)| path.clone()).collect();
        assert_eq!(paths.len(), 2, "{paths:?}");
        assert!(
            paths
                .iter()
                .all(|path| path.starts_with(config_home.join("qt6ct")))
        );
    }

    #[test]
    fn config_merge_preserves_unrelated_tool_settings() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let tool_dir = config_home.join("qt6ct");
        std::fs::create_dir_all(&tool_dir).unwrap();
        std::fs::write(
            tool_dir.join("qt6ct.conf"),
            "; my qt6ct settings\n[Appearance]\nstyle=Fusion\ncustom_palette=false\n\n\
             [Fonts]\ngeneral=Noto Sans\n",
        )
        .unwrap();

        let mut adapter = QtAdapter::with_targets(config_home.clone(), false, true);
        adapter.set_unique_theme_name("rde-dynamic-dark-v3".to_string());
        let output = adapter.render(&theme()).unwrap();
        for (path, bytes) in &output.files {
            crate::fs::write_atomic(path, bytes).unwrap();
        }

        let config = std::fs::read_to_string(tool_dir.join("qt6ct.conf")).unwrap();
        assert!(config.contains("; my qt6ct settings"), "{config}");
        assert!(config.contains("style=Fusion"), "{config}");
        assert!(config.contains("[Fonts]"), "{config}");
        assert!(config.contains("general=Noto Sans"), "{config}");
        assert!(config.contains("custom_palette=true"), "{config}");
        assert!(config.contains("color_scheme_path="), "{config}");
    }

    #[test]
    fn supersedes_only_the_palettes_of_the_same_variant() {
        let temp = tempfile::tempdir().unwrap();
        let config_home = temp.path().join("config");
        let colors_dir = config_home.join("qt5ct").join("colors");
        std::fs::create_dir_all(&colors_dir).unwrap();

        // A palette generated for an earlier generation, a user palette, and
        // the palette of the other variant.
        std::fs::write(colors_dir.join("rde-dynamic-dark-v1.conf"), "stale").unwrap();
        std::fs::write(colors_dir.join("Solarized.conf"), "user palette").unwrap();
        std::fs::write(colors_dir.join("rde-dynamic-light-v1.conf"), "other").unwrap();

        let mut adapter = QtAdapter::with_targets(config_home, true, false);
        adapter.set_unique_theme_name("rde-dynamic-dark-v2".to_string());
        let output = adapter.render(&theme()).unwrap();

        assert_eq!(
            output.removals,
            vec![colors_dir.join("rde-dynamic-dark-v1.conf")]
        );
        assert!(
            output
                .files
                .iter()
                .any(|(path, _)| path.ends_with("rde-dynamic-dark-v2.conf")),
            "{output:?}"
        );
    }

    #[test]
    fn maps_material_roles_onto_qpalette_order() {
        let colors = roles();
        let palette = render_qtct_palette(&colors);

        let active = group_values(&palette, "active_colors");
        assert_eq!(active[0], qtct_color(&colors.on_surface)); // WindowText
        assert_eq!(active[10], qtct_color(&colors.surface)); // Window
        assert_eq!(active[12], qtct_color(&colors.primary)); // Highlight
        assert_eq!(active[15], qtct_color(&colors.tertiary)); // LinkVisited
        assert_eq!(active[19], qtct_color(&colors.inverse_on_surface)); // ToolTipText
        assert_eq!(active[20], qtct_color(&colors.on_surface_variant)); // Placeholder
        assert_eq!(active[21], qtct_color(&colors.primary)); // Accent

        let disabled = group_values(&palette, "disabled_colors");
        assert_eq!(disabled[0], qtct_color(&colors.outline)); // WindowText
        assert_eq!(disabled[6], qtct_color(&colors.outline)); // Text
    }
}
