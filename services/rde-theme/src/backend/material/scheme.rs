//! # Material 3 Scheme and Palette Generation
//!
//! Implements deterministic Material 3 color generation from the four dynamic
//! seed colors.
//!
//! Changing [`MATERIAL_ALGORITHM_VERSION`] alters the generated theme colors,
//! requiring either suppressing `ThemeChanged` or accepting a single repaint on
//! daemon upgrade.

use material_color_utilities::{
    dynamiccolor::{DynamicScheme, DynamicSchemeBuilder, SpecVersion, Variant},
    hct::Hct,
};

use crate::domain::{
    manifest::{ContrastLevel, ThemeMode},
    resolved::{Color, ColorRoles, ColorSeeds},
};

/// Deterministic algorithm version for the Material 3 scheme derivation.
///
/// Bumped to 3 when each role family started deriving its palette from its own
/// seed color; consumers may see one repaint on upgrade.
pub const MATERIAL_ALGORITHM_VERSION: u32 = 3;

/// Fallback seed color (Google Blue `#4285f4`) used when no user seed is available.
pub use crate::domain::resolved::FALLBACK_SEED_COLOR;

/// The four roles one seed produces, using the standard Material tones.
struct SeedFamily {
    /// Base role (`40` in light, `80` in dark).
    base: u32,

    /// Content role placed on top of [`Self::base`] (`100` light, `20` dark).
    on_base: u32,

    /// Container role (`90` light, `30` dark).
    container: u32,

    /// Content role placed inside [`Self::container`] (`10` light, `90` dark).
    on_container: u32,
}

/// Builds one Material 3 dynamic scheme for a seed, appearance, and contrast.
///
/// # Parameters
/// - `seed`: `#RRGGBB` color the scheme derives its palettes from
/// - `is_dark`: whether the scheme renders the dark appearance
/// - `contrast_level`: Material contrast level (`0.0`, `0.5`, or `1.0`)
/// - `spec`: Material color specification used for the role calculation
fn build_scheme(
    seed: &Color,
    is_dark: bool,
    contrast_level: f64,
    spec: SpecVersion,
) -> DynamicScheme {
    DynamicSchemeBuilder::default()
        .source_color_hct(Hct::from_int(parse_hex_to_argb(seed.as_str())))
        .variant(Variant::TonalSpot)
        .is_dark(is_dark)
        .contrast_level(contrast_level)
        .spec_version(spec)
        .build()
}

/// Resolves one seed into its base, content, container, and container-content roles.
///
/// The four Material role families share the same tone structure, so one helper
/// serves primary, secondary, tertiary, and error. The scheme is built per seed,
/// which means a family takes both the hue and the chroma of its own seed.
///
/// # Parameters
/// - `seed`: color the family's palette is generated from
/// - `is_dark`: whether the dark appearance is rendered
/// - `contrast_level`: Material contrast level
/// - `normal_contrast`: whether the canonical container tones are used
fn seed_family(
    seed: &Color,
    is_dark: bool,
    contrast_level: f64,
    normal_contrast: bool,
) -> SeedFamily {
    let scheme = build_scheme(seed, is_dark, contrast_level, SpecVersion::Spec2021);

    // Material's 2021 tone-delta rules are implemented on the wrong side of the
    // container pair by this crate, which makes dark schemes carry light
    // containers (and light schemes dark ones). At normal contrast use the
    // canonical container tones directly; for the accessibility levels use the
    // 2025 calculation, which keeps containers on the correct side and honors
    // the extra contrast.
    let (container, on_container) = if normal_contrast {
        let (tone, on_tone) = if is_dark { (30u8, 90u8) } else { (90u8, 30u8) };
        let palette = scheme.primary_palette();
        (palette.tone(tone), palette.tone(on_tone))
    } else {
        let accessibility = build_scheme(seed, is_dark, contrast_level, SpecVersion::Spec2025);
        (
            accessibility.primary_container(),
            accessibility.on_primary_container(),
        )
    };

    SeedFamily {
        base: scheme.primary(),
        on_base: scheme.on_primary(),
        container,
        on_container,
    }
}

/// Computes a complete [`ColorRoles`] struct from the four seed colors, mode, and contrast.
///
/// Each role family is generated from its own seed; the neutral surfaces,
/// outlines, and inverse roles follow the primary seed so the desktop keeps one
/// coherent background.
///
/// # Parameters
/// - `seeds`: primary, secondary, tertiary, and error seeds
/// - `mode`: Light or Dark appearance
/// - `contrast`: Normal, Medium, or High contrast
///
/// # Returns
/// A populated [`ColorRoles`] containing all 34 M3 semantic color roles.
pub fn compute_color_roles(
    seeds: &ColorSeeds,
    mode: ThemeMode,
    contrast: ContrastLevel,
) -> ColorRoles {
    let is_dark = match mode {
        ThemeMode::Light => false,
        ThemeMode::Dark => true,
    };

    let contrast_level = match contrast {
        ContrastLevel::Normal => 0.0,
        ContrastLevel::Medium => 0.5,
        ContrastLevel::High => 1.0,
    };

    let normal_contrast = contrast == ContrastLevel::Normal;

    // Step 1: Resolve the four role families, one per seed.
    let primary = seed_family(&seeds.primary, is_dark, contrast_level, normal_contrast);
    let secondary = seed_family(&seeds.secondary, is_dark, contrast_level, normal_contrast);
    let tertiary = seed_family(&seeds.tertiary, is_dark, contrast_level, normal_contrast);
    let error = seed_family(&seeds.error, is_dark, contrast_level, normal_contrast);

    // Step 2: Resolve the neutral roles from the primary scheme so surfaces,
    // outlines, and scrims stay tied to the accent color.
    let scheme = build_scheme(
        &seeds.primary,
        is_dark,
        contrast_level,
        SpecVersion::Spec2021,
    );

    ColorRoles {
        primary: Color::from_argb_u32(primary.base),
        on_primary: Color::from_argb_u32(primary.on_base),
        primary_container: Color::from_argb_u32(primary.container),
        on_primary_container: Color::from_argb_u32(primary.on_container),
        secondary: Color::from_argb_u32(secondary.base),
        on_secondary: Color::from_argb_u32(secondary.on_base),
        secondary_container: Color::from_argb_u32(secondary.container),
        on_secondary_container: Color::from_argb_u32(secondary.on_container),
        tertiary: Color::from_argb_u32(tertiary.base),
        on_tertiary: Color::from_argb_u32(tertiary.on_base),
        tertiary_container: Color::from_argb_u32(tertiary.container),
        on_tertiary_container: Color::from_argb_u32(tertiary.on_container),
        error: Color::from_argb_u32(error.base),
        on_error: Color::from_argb_u32(error.on_base),
        error_container: Color::from_argb_u32(error.container),
        on_error_container: Color::from_argb_u32(error.on_container),
        background: Color::from_argb_u32(scheme.background()),
        on_background: Color::from_argb_u32(scheme.on_background()),
        surface: Color::from_argb_u32(scheme.surface()),
        on_surface: Color::from_argb_u32(scheme.on_surface()),
        surface_variant: Color::from_argb_u32(scheme.surface_variant()),
        on_surface_variant: Color::from_argb_u32(scheme.on_surface_variant()),
        surface_container_lowest: Color::from_argb_u32(scheme.surface_container_lowest()),
        surface_container_low: Color::from_argb_u32(scheme.surface_container_low()),
        surface_container: Color::from_argb_u32(scheme.surface_container()),
        surface_container_high: Color::from_argb_u32(scheme.surface_container_high()),
        surface_container_highest: Color::from_argb_u32(scheme.surface_container_highest()),
        outline: Color::from_argb_u32(scheme.outline()),
        outline_variant: Color::from_argb_u32(scheme.outline_variant()),
        shadow: Color::from_argb_u32(scheme.shadow()),
        scrim: Color::from_argb_u32(scheme.scrim()),
        inverse_surface: Color::from_argb_u32(scheme.inverse_surface()),
        inverse_on_surface: Color::from_argb_u32(scheme.inverse_on_surface()),
        inverse_primary: Color::from_argb_u32(scheme.inverse_primary()),
    }
}

/// Helper parsing `#RRGGBB` into opaque 32-bit ARGB.
fn parse_hex_to_argb(hex: &str) -> u32 {
    let clean = hex.trim_start_matches('#');
    if let Ok(val) = u32::from_str_radix(clean, 16) {
        0xFF00_0000 | (val & 0x00FF_FFFF)
    } else {
        0xFF42_85F4 // Default to Google Blue if parse fails
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a seed set from four `#RRGGBB` literals.
    fn seeds(primary: &str, secondary: &str, tertiary: &str, error: &str) -> ColorSeeds {
        ColorSeeds {
            primary: Color::new(primary).unwrap(),
            secondary: Color::new(secondary).unwrap(),
            tertiary: Color::new(tertiary).unwrap(),
            error: Color::new(error).unwrap(),
        }
    }

    /// Builds a seed set where every family uses the same color.
    fn uniform(seed: &str) -> ColorSeeds {
        ColorSeeds::uniform(&Color::new(seed).unwrap())
    }

    #[test]
    fn test_compute_color_roles_determinism() {
        let seeds = uniform("#006a6a");
        let roles1 = compute_color_roles(&seeds, ThemeMode::Dark, ContrastLevel::Normal);
        let roles2 = compute_color_roles(&seeds, ThemeMode::Dark, ContrastLevel::Normal);
        assert_eq!(roles1, roles2);

        let light = compute_color_roles(&seeds, ThemeMode::Light, ContrastLevel::Normal);
        assert_ne!(roles1.surface, light.surface);
    }

    #[test]
    fn primary_family_matches_the_flutter_color_scheme() {
        let seeds = uniform("#6750A4");

        // Values produced by Flutter's `ColorScheme.fromSeed` for the same seed.
        let dark = compute_color_roles(&seeds, ThemeMode::Dark, ContrastLevel::Normal);
        assert_eq!(dark.primary.as_str(), "#cfbdfe");
        assert_eq!(dark.on_primary.as_str(), "#36275d");
        assert_eq!(dark.primary_container.as_str(), "#4d3d75");
        assert_eq!(dark.on_primary_container.as_str(), "#e9ddff");
        assert_eq!(dark.surface.as_str(), "#141218");

        let light = compute_color_roles(&seeds, ThemeMode::Light, ContrastLevel::Normal);
        assert_eq!(light.primary.as_str(), "#65558f");
        assert_eq!(light.primary_container.as_str(), "#e9ddff");
        assert_eq!(light.on_primary_container.as_str(), "#4d3d75");
        assert_eq!(light.surface.as_str(), "#fdf7ff");
    }

    #[test]
    fn each_family_is_generated_from_its_own_seed() {
        let base = seeds("#6750A4", "#006A6A", "#B52700", "#BA1A1A");
        let roles = compute_color_roles(&base, ThemeMode::Dark, ContrastLevel::Normal);

        // Changing one seed must only repaint that family.
        let other_secondary = compute_color_roles(
            &seeds("#6750A4", "#006E3C", "#B52700", "#BA1A1A"),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        );
        assert_eq!(roles.primary, other_secondary.primary);
        assert_eq!(roles.tertiary, other_secondary.tertiary);
        assert_eq!(roles.error, other_secondary.error);
        assert_ne!(roles.secondary, other_secondary.secondary);
        assert_ne!(
            roles.secondary_container,
            other_secondary.secondary_container
        );

        // The error family follows its seed instead of the fixed Material red.
        let other_error = compute_color_roles(
            &seeds("#6750A4", "#006A6A", "#B52700", "#B90063"),
            ThemeMode::Dark,
            ContrastLevel::Normal,
        );
        assert_ne!(roles.error, other_error.error);
        assert_eq!(roles.secondary, other_error.secondary);
    }

    #[test]
    fn high_contrast_keeps_every_family_on_its_seed() {
        let base = seeds("#6750A4", "#006A6A", "#B52700", "#BA1A1A");
        let normal = compute_color_roles(&base, ThemeMode::Dark, ContrastLevel::Normal);
        let high = compute_color_roles(&base, ThemeMode::Dark, ContrastLevel::High);

        assert_ne!(normal.primary, high.primary);
        assert_ne!(normal.secondary, high.secondary);
        assert_ne!(normal.tertiary, high.tertiary);
        assert_ne!(normal.error, high.error);
    }
}
