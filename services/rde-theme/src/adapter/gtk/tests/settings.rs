//! # GTK settings.ini Tests
//!
//! Guards the non-destructive merge: only the two appearance keys change, and
//! a missing section is appended instead of replacing the document.

use crate::adapter::gtk::settings::merge_settings_ini;

#[test]
fn merge_updates_appearance_and_preserves_unrelated_keys() {
    let existing = "; hand-written\n[Settings]\ngtk-font-name=Cantarell 11\n\
                    gtk-theme-name=Adwaita\ngtk-cursor-theme-name=Adwaita\n\
                    gtk-application-prefer-dark-theme=false\n\n\
                    [Other]\nkey=value\n";

    let merged = merge_settings_ini(existing, "rde-gtk-m3-v7", true);

    assert!(merged.contains("; hand-written"), "{merged}");
    assert!(merged.contains("gtk-font-name=Cantarell 11"), "{merged}");
    assert!(merged.contains("gtk-cursor-theme-name=Adwaita"), "{merged}");
    assert!(merged.contains("[Other]\nkey=value"), "{merged}");
    assert!(merged.contains("gtk-theme-name=rde-gtk-m3-v7"), "{merged}");
    assert!(
        merged.contains("gtk-application-prefer-dark-theme=true"),
        "{merged}"
    );
    // The old values are replaced, not duplicated.
    assert_eq!(merged.matches("gtk-theme-name=").count(), 1, "{merged}");
    assert_eq!(
        merged.matches("gtk-application-prefer-dark-theme=").count(),
        1,
        "{merged}"
    );
}

#[test]
fn appends_the_settings_group_when_it_is_missing() {
    let merged = merge_settings_ini("gtk-font-name=Cantarell 11\n", "rde-gtk-m3-v7", false);

    assert_eq!(
        merged,
        "gtk-font-name=Cantarell 11\n\n[Settings]\ngtk-theme-name=rde-gtk-m3-v7\n\
         gtk-application-prefer-dark-theme=false\n"
    );
}
