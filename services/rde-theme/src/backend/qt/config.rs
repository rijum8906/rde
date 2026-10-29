//! # qt5ct / qt6ct Config Merging
//!
//! Updates only the palette selection in a tool's configuration file, so the
//! user's style, icons, fonts, comments, and unrelated keys survive.

use std::path::Path;

/// Section of a qt5ct/qt6ct config file that selects the palette.
const QTCT_CONFIG_SECTION: &str = "Appearance";

/// Updates the palette selection in a qt5ct/qt6ct config document.
///
/// Everything else (style, icons, fonts, comments) is preserved, so switching
/// palettes never resets the user's tool configuration.
pub(crate) fn merge_qtct_config(existing: &str, palette_path: &Path) -> String {
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
pub(crate) fn read_optional(path: &Path) -> String {
    std::fs::read_to_string(path).unwrap_or_default()
}
