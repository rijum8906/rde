//! # Qt Adapter Behavior Tests
//!
//! Covers which tools are written, how the palette is installed, and that
//! stale palettes are removed without touching user files.

use super::super::QtAdapter;
use super::{group_values, theme};
use crate::adapter::Adapter;

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
