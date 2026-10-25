//! # Material 3 Scheme and Palette Generation
//!
//! Implements deterministic Material 3 color generation from seed colors and wallpapers.
//!
//! Changing [`MATERIAL_ALGORITHM_VERSION`] or [`SEED_EXTRACTOR_VERSION`] alters the
//! generated theme colors, requiring either suppressing `ThemeChanged` or accepting
//! a single repaint on daemon upgrade.

use material_color_utilities::{
    dynamiccolor::{DynamicSchemeBuilder, Variant},
    hct::Hct,
    score::score_with,
};
use std::{collections::HashMap, path::Path};
use tracing::warn;

use crate::domain::{
    manifest::{ContrastLevel, ThemeMode},
    resolved::{Color, ColorRoles},
};

/// Deterministic algorithm version for the Material 3 scheme derivation.
pub const MATERIAL_ALGORITHM_VERSION: u32 = 1;

/// Deterministic algorithm version for extracting seed colors from wallpapers.
pub const SEED_EXTRACTOR_VERSION: u32 = 1;

/// Fallback seed color (Google Blue `#4285f4`) when no wallpaper or custom seed is provided.
pub use crate::domain::resolved::FALLBACK_SEED_COLOR;

/// Computes a complete [`ColorRoles`] struct from a seed [`Color`], mode, and contrast.
///
/// # Parameters
/// - `seed`: base seed color
/// - `mode`: Light or Dark appearance
/// - `contrast`: Normal, Medium, or High contrast
///
/// # Returns
/// A populated [`ColorRoles`] containing all 34 M3 semantic color roles.
pub fn compute_color_roles(seed: &Color, mode: ThemeMode, contrast: ContrastLevel) -> ColorRoles {
    let argb = parse_hex_to_argb(seed.as_str());
    let hct = Hct::from_int(argb);

    let is_dark = match mode {
        ThemeMode::Light => false,
        ThemeMode::Dark => true,
    };

    let contrast_level = match contrast {
        ContrastLevel::Normal => 0.0,
        ContrastLevel::Medium => 0.5,
        ContrastLevel::High => 1.0,
    };

    let scheme = DynamicSchemeBuilder::default()
        .source_color_hct(hct)
        .variant(Variant::TonalSpot)
        .is_dark(is_dark)
        .contrast_level(contrast_level)
        .build();

    ColorRoles {
        primary: Color::from_argb_u32(scheme.primary()),
        on_primary: Color::from_argb_u32(scheme.on_primary()),
        primary_container: Color::from_argb_u32(scheme.primary_container()),
        on_primary_container: Color::from_argb_u32(scheme.on_primary_container()),
        secondary: Color::from_argb_u32(scheme.secondary()),
        on_secondary: Color::from_argb_u32(scheme.on_secondary()),
        secondary_container: Color::from_argb_u32(scheme.secondary_container()),
        on_secondary_container: Color::from_argb_u32(scheme.on_secondary_container()),
        tertiary: Color::from_argb_u32(scheme.tertiary()),
        on_tertiary: Color::from_argb_u32(scheme.on_tertiary()),
        tertiary_container: Color::from_argb_u32(scheme.tertiary_container()),
        on_tertiary_container: Color::from_argb_u32(scheme.on_tertiary_container()),
        error: Color::from_argb_u32(scheme.error()),
        on_error: Color::from_argb_u32(scheme.on_error()),
        error_container: Color::from_argb_u32(scheme.error_container()),
        on_error_container: Color::from_argb_u32(scheme.on_error_container()),
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

/// Extracts a representative dominant seed color from a wallpaper image.
///
/// # Algorithm (Pinned under [`SEED_EXTRACTOR_VERSION`])
/// 1. Reads image from `path`.
/// 2. Downsamples to 128x128 pixels using nearest-neighbor sampling.
/// 3. Builds a color population histogram of opaque ARGB values.
/// 4. Scores candidate colors using Material Design 3 color suitability heuristics.
/// 5. Returns the top-ranked color, falling back to [`FALLBACK_SEED_COLOR`] on error.
#[must_use]
pub fn extract_seed_from_wallpaper(image_path: &Path) -> Color {
    // Step 1: Open image file.
    let img = match image::open(image_path) {
        Ok(img) => img,
        Err(err) => {
            warn!(path = %image_path.display(), error = %err, "Failed to open wallpaper image; using fallback seed");
            return Color::fallback();
        }
    };

    // Step 2: Downsample to 128x128 for deterministic, fast quantification.
    let small = img.resize_exact(128, 128, image::imageops::FilterType::Nearest);
    let rgb_img = small.to_rgb8();

    // Step 3: Populate histogram of ARGB colors.
    let mut population: HashMap<u32, u16> = HashMap::new();
    for pixel in rgb_img.pixels() {
        let r = pixel[0] as u32;
        let g = pixel[1] as u32;
        let b = pixel[2] as u32;
        let argb = 0xFF00_0000 | (r << 16) | (g << 8) | b;
        let count = population.entry(argb).or_insert(0);
        *count = count.saturating_add(1);
    }

    // Step 4: Score colors via M3 scoring algorithm.
    let ranked = score_with(population, Some(1), None, Some(true));

    if let Some(&top_argb) = ranked.first() {
        Color::from_argb_u32(top_argb)
    } else {
        Color::fallback()
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

    #[test]
    fn test_compute_color_roles_determinism() {
        let seed = Color::new("#006a6a").unwrap();
        let roles1 = compute_color_roles(&seed, ThemeMode::Dark, ContrastLevel::Normal);
        let roles2 = compute_color_roles(&seed, ThemeMode::Dark, ContrastLevel::Normal);
        assert_eq!(roles1, roles2);

        let light = compute_color_roles(&seed, ThemeMode::Light, ContrastLevel::Normal);
        assert_ne!(roles1.surface, light.surface);
    }

    #[test]
    fn test_extract_seed_fallback_on_missing_file() {
        let nonexistent = Path::new("/nonexistent/wallpaper.png");
        let seed = extract_seed_from_wallpaper(nonexistent);
        assert_eq!(seed.as_str(), FALLBACK_SEED_COLOR);
    }
}
