//! # Minimal INI Editor
//!
//! Comment-preserving INI document used to update the user's existing Qt and
//! KDE configuration. Qt's `QSettings` and KDE's `KConfig` both use an INI-like
//! format where only a handful of keys belong to the theme service; rewriting
//! the whole file would discard unrelated user settings.
//!
//! ## Features
//! - Preserves comments, blank lines, ordering, and unknown sections/keys
//! - Updates an existing key in place, inserts a missing key at the end of its
//!   section, and appends a missing section
//! - CRLF input is normalized to `\n` via [`str::lines`]
//!
//! ## Related
//! - [`super::kde`]: merges a color scheme into `kdeglobals`
//! - [`super::qtct`]: activates the generated scheme in `qt5ct/qt6ct` configs
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

/// Line-oriented INI document that preserves everything it does not modify.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct IniDocument {
    /// Raw document lines without line terminators.
    lines: Vec<String>,
}

impl IniDocument {
    /// Parses an INI document.
    ///
    /// # Parameters
    /// - `contents`: file contents; may be empty
    pub fn parse(contents: &str) -> Self {
        Self {
            lines: contents.lines().map(str::to_string).collect(),
        }
    }

    /// Returns the value of a key inside a section.
    ///
    /// # Parameters
    /// - `section`: section name without brackets
    /// - `key`: key name without the trailing `=`
    ///
    /// # Returns
    /// The trimmed value, or `None` when the section or key is absent.
    #[cfg(test)]
    pub fn get(&self, section: &str, key: &str) -> Option<&str> {
        let (start, end) = self.section_range(section)?;

        self.lines[start + 1..end].iter().find_map(|line| {
            let (line_key, value) = split_entry(line)?;
            (line_key == key).then_some(value)
        })
    }

    /// Sets a key inside a section, preserving all other content.
    ///
    /// # Parameters
    /// - `section`: section name without brackets; created when missing
    /// - `key`: key name without the trailing `=`
    /// - `value`: raw value; written verbatim
    pub fn set(&mut self, section: &str, key: &str, value: &str) {
        let entry = format!("{key}={value}");

        // Step 1: Update in place or append to an existing section.
        if let Some((start, end)) = self.section_range(section) {
            if let Some(index) = (start + 1..end).find(|index| {
                split_entry(&self.lines[*index]).map(|(line_key, _)| line_key) == Some(key)
            }) {
                self.lines[index] = entry;
            } else {
                self.lines.insert(end, entry);
            }
            return;
        }

        // Step 2: Append a new section, separated from the previous content.
        if self
            .lines
            .last()
            .is_some_and(|line| !line.trim().is_empty())
        {
            self.lines.push(String::new());
        }
        self.lines.push(format!("[{section}]"));
        self.lines.push(entry);
    }

    /// Renders the document with a trailing newline.
    pub fn to_document(&self) -> String {
        if self.lines.is_empty() {
            return String::new();
        }

        let mut document = self.lines.join("\n");
        document.push('\n');
        document
    }

    /// Returns the index range of a section body (`start..end`).
    ///
    /// `start` points at the section header; `end` points at the next header or
    /// the end of the document.
    fn section_range(&self, section: &str) -> Option<(usize, usize)> {
        let mut start = None;

        for (index, line) in self.lines.iter().enumerate() {
            let Some(name) = section_name(line) else {
                continue;
            };

            if let Some(start) = start {
                return Some((start, index));
            }
            if name == section {
                start = Some(index);
            }
        }

        start.map(|start| (start, self.lines.len()))
    }
}

/// Extracts the section name from a `[section]` header line.
fn section_name(line: &str) -> Option<&str> {
    let trimmed = line.trim();
    let rest = trimmed.strip_prefix('[')?;

    rest.split(']').next()
}

/// Splits a `key=value` line into its trimmed key and trimmed value.
fn split_entry(line: &str) -> Option<(&str, &str)> {
    let trimmed = line.trim();

    // Comments, blank lines, and section headers are not entries.
    if trimmed.is_empty()
        || trimmed.starts_with('#')
        || trimmed.starts_with(';')
        || trimmed.starts_with('[')
    {
        return None;
    }

    let (key, value) = trimmed.split_once('=')?;
    Some((key.trim(), value.trim()))
}

#[cfg(test)]
mod tests {
    use super::*;

    const CONFIG: &str = "\
# qt5ct settings
[Appearance]
style=Fusion
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
custom_palette=false

[Interface]
menus_have_icons=true
";

    #[test]
    fn reads_values_and_comments_are_ignored() {
        let document = IniDocument::parse(CONFIG);

        assert_eq!(document.get("Appearance", "style"), Some("Fusion"));
        assert_eq!(
            document.get("Appearance", "color_scheme_path"),
            Some("/usr/share/qt5ct/colors/darker.conf")
        );
        assert_eq!(document.get("Interface", "menus_have_icons"), Some("true"));
        assert_eq!(document.get("Appearance", "missing"), None);
        assert_eq!(document.get("Missing", "key"), None);
    }

    #[test]
    fn updates_existing_keys_without_touching_other_lines() {
        let mut document = IniDocument::parse(CONFIG);
        document.set(
            "Appearance",
            "color_scheme_path",
            "/home/user/.config/qt5ct/colors/RdeM3.conf",
        );
        document.set("Appearance", "custom_palette", "true");

        let rendered = document.to_document();
        assert!(rendered.starts_with("# qt5ct settings\n"));
        assert!(rendered.contains("[Appearance]\nstyle=Fusion\ncolor_scheme_path=/home/user/.config/qt5ct/colors/RdeM3.conf\ncustom_palette=true\n"));
        assert!(rendered.contains("[Interface]\nmenus_have_icons=true\n"));
        assert_eq!(
            document.get("Appearance", "color_scheme_path"),
            Some("/home/user/.config/qt5ct/colors/RdeM3.conf")
        );
    }

    #[test]
    fn inserts_missing_keys_and_sections() {
        let mut document = IniDocument::parse("[Appearance]\nstyle=Fusion\n");

        document.set("Appearance", "custom_palette", "true");
        document.set("Fonts", "general", "Inter,10");

        let rendered = document.to_document();
        assert!(rendered.contains("[Appearance]\nstyle=Fusion\ncustom_palette=true"));
        assert!(rendered.ends_with("[Fonts]\ngeneral=Inter,10\n"));
        assert_eq!(document.get("Fonts", "general"), Some("Inter,10"));
    }

    #[test]
    fn empty_documents_are_created_cleanly() {
        let mut document = IniDocument::parse("");

        document.set("Appearance", "color_scheme_path", "/tmp/RdeM3.conf");

        assert_eq!(
            document.to_document(),
            "[Appearance]\ncolor_scheme_path=/tmp/RdeM3.conf\n"
        );
    }

    #[test]
    fn setting_the_same_value_twice_is_idempotent() {
        let mut document = IniDocument::parse(CONFIG);
        document.set("Appearance", "custom_palette", "true");
        let once = document.to_document();

        document.set("Appearance", "custom_palette", "true");

        assert_eq!(document.to_document(), once);
    }
}
