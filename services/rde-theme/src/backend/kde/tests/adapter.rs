//! # KDE Adapter Behavior Tests
//!
//! Covers the files the adapter publishes, the merge into an existing
//! `kdeglobals`, and the cleanup of superseded schemes.

use super::theme;
use crate::{
    backend::{
        Adapter,
        kde::{KdeAdapter, color_schemes_dir, kde_color_scheme_name},
    },
    fs::write_atomic,
};

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
    let scheme_name = kde_color_scheme_name(&resolved_theme.theme_id, &resolved_theme.variant, 3);
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
        write_atomic(path, bytes).unwrap();
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
