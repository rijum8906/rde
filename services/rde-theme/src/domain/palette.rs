//! # Semantic Color Palette
//!
//! Toolkit-neutral color roles (primary, surface, outline, ...) produced by a
//! backend and consumed by every toolkit writer.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::domain::color::format_hex_color;

/// Complete set of semantic color roles for a single appearance scheme.
///
/// # Fields
/// - `primary`, `on_primary`, `primary_container`, `on_primary_container`:
///   high-emphasis action colors
/// - `secondary`, `on_secondary`, `secondary_container`,
///   `on_secondary_container`: secondary UI colors
/// - `tertiary`, `on_tertiary`, `tertiary_container`, `on_tertiary_container`:
///   accent colors
/// - `error`, `on_error`, `error_container`, `on_error_container`: destructive
///   action colors
/// - `background`, `on_background`: legacy background roles
/// - `surface`, `surface_dim`, `surface_bright`, `on_surface`,
///   `surface_variant`, `on_surface_variant`: window and panel backgrounds
/// - `surface_container_lowest` .. `surface_container_highest`: elevation tiers
/// - `surface_tint`: brand tint applied to elevated surfaces
/// - `inverse_surface`, `inverse_on_surface`, `inverse_primary`: high-contrast
///   overlays such as snackbars and tooltips
/// - `outline`, `outline_variant`: borders and dividers
/// - `shadow`, `scrim`: elevation and modal overlays
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Palette {
    /// High-emphasis action color.
    pub primary: u32,
    /// Foreground color on `primary`.
    pub on_primary: u32,
    /// Container fill for featured elements.
    pub primary_container: u32,
    /// Foreground color on `primary_container`.
    pub on_primary_container: u32,

    /// Lower-emphasis UI color.
    pub secondary: u32,
    /// Foreground color on `secondary`.
    pub on_secondary: u32,
    /// Container fill for secondary elements.
    pub secondary_container: u32,
    /// Foreground color on `secondary_container`.
    pub on_secondary_container: u32,

    /// Complementary accent color.
    pub tertiary: u32,
    /// Foreground color on `tertiary`.
    pub on_tertiary: u32,
    /// Container fill for tertiary elements.
    pub tertiary_container: u32,
    /// Foreground color on `tertiary_container`.
    pub on_tertiary_container: u32,

    /// Error and destructive action color.
    pub error: u32,
    /// Foreground color on `error`.
    pub on_error: u32,
    /// Container fill for error banners and dialogs.
    pub error_container: u32,
    /// Foreground color on `error_container`.
    pub on_error_container: u32,

    /// Legacy background color.
    pub background: u32,
    /// Foreground color on `background`.
    pub on_background: u32,

    /// Standard window and panel background.
    pub surface: u32,
    /// Dimmed surface used for large dark areas.
    pub surface_dim: u32,
    /// Brightened surface used for large light areas.
    pub surface_bright: u32,
    /// Primary text and high-emphasis icons on `surface`.
    pub on_surface: u32,
    /// Subtle surface variant behind cards and dividers.
    pub surface_variant: u32,
    /// Medium-emphasis text on `surface_variant`.
    pub on_surface_variant: u32,

    /// Lowest elevation surface container.
    pub surface_container_lowest: u32,
    /// Low elevation surface container.
    pub surface_container_low: u32,
    /// Default surface container (cards, sidebars).
    pub surface_container: u32,
    /// High elevation surface container.
    pub surface_container_high: u32,
    /// Highest elevation surface container (menus, dialogs).
    pub surface_container_highest: u32,
    /// Tint color used on elevated surfaces.
    pub surface_tint: u32,

    /// High-contrast surface for snackbars and toasts.
    pub inverse_surface: u32,
    /// Foreground color on `inverse_surface`.
    pub inverse_on_surface: u32,
    /// Action color used inside `inverse_surface`.
    pub inverse_primary: u32,

    /// Structural borders and dividers.
    pub outline: u32,
    /// Low-contrast border tint.
    pub outline_variant: u32,

    /// Shadow tint for elevation.
    pub shadow: u32,
    /// Modal backdrop overlay.
    pub scrim: u32,
}

impl Palette {
    /// Returns every color role keyed by its canonical snake_case name.
    ///
    /// The map is ordered so repeated calls and D-Bus replies are stable, which
    /// makes it straightforward for CLIs, shells, and toolkit writers to
    /// consume the palette without knowing the struct layout.
    ///
    /// # Returns
    /// A map from role name (e.g. `primary_container`) to `#RRGGBB`.
    pub fn role_map(&self) -> BTreeMap<String, String> {
        [
            ("primary", self.primary),
            ("on_primary", self.on_primary),
            ("primary_container", self.primary_container),
            ("on_primary_container", self.on_primary_container),
            ("secondary", self.secondary),
            ("on_secondary", self.on_secondary),
            ("secondary_container", self.secondary_container),
            ("on_secondary_container", self.on_secondary_container),
            ("tertiary", self.tertiary),
            ("on_tertiary", self.on_tertiary),
            ("tertiary_container", self.tertiary_container),
            ("on_tertiary_container", self.on_tertiary_container),
            ("error", self.error),
            ("on_error", self.on_error),
            ("error_container", self.error_container),
            ("on_error_container", self.on_error_container),
            ("background", self.background),
            ("on_background", self.on_background),
            ("surface", self.surface),
            ("surface_dim", self.surface_dim),
            ("surface_bright", self.surface_bright),
            ("on_surface", self.on_surface),
            ("surface_variant", self.surface_variant),
            ("on_surface_variant", self.on_surface_variant),
            ("surface_container_lowest", self.surface_container_lowest),
            ("surface_container_low", self.surface_container_low),
            ("surface_container", self.surface_container),
            ("surface_container_high", self.surface_container_high),
            ("surface_container_highest", self.surface_container_highest),
            ("surface_tint", self.surface_tint),
            ("inverse_surface", self.inverse_surface),
            ("inverse_on_surface", self.inverse_on_surface),
            ("inverse_primary", self.inverse_primary),
            ("outline", self.outline),
            ("outline_variant", self.outline_variant),
            ("shadow", self.shadow),
            ("scrim", self.scrim),
        ]
        .into_iter()
        .map(|(role, color)| (role.to_string(), format_hex_color(color)))
        .collect()
    }
}
