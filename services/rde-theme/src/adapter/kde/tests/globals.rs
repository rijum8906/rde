//! # kdeglobals Render and Merge Tests
//!
//! Guards that every owned group and key is emitted, that `ColorScheme` stays
//! owned by the apply tool, and that merging preserves the user's document.

use super::super::globals::OWNED_SECTIONS;
use super::roles;
use crate::adapter::kde::{merge_kdeglobals, render_kdeglobals};

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
