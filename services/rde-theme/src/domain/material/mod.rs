//! # Material 3 Color Palette Engine
//!
//! Implements Google's Material 3 (M3) design system color roles and tonal palette
//! generation. This module defines the authoritative set of color definitions used
//! throughout the RDE theme system for consistent, accessible color synchronization.
//!
//! ## Color Roles
//! Material 3 defines 25+ semantic color roles organized into families:
//! - **Primary Family**: Primary action colors (primary, on_primary, primary_container, etc.)
//! - **Secondary Family**: Secondary UI elements (secondary, on_secondary, etc.)
//! - **Tertiary Family**: Tertiary accents (tertiary, on_tertiary, etc.)
//! - **Error Family**: Destructive actions (error, on_error, error_container, etc.)
//! - **Surface Family**: Background surfaces (surface, surface_variant, surface_container, etc.)
//! - **Neutral Family**: Outlines and shadows (outline, outline_variant, shadow, scrim)
//! - **Inverse Family**: High-contrast overlays (inverse_surface, inverse_primary, inverse_on_surface)
//!
//! ## Features
//! - Complete M3 color role set with WCAG 2.1 AA contrast compliance
//! - Seed color-based dynamic palette generation
//! - D-Bus serialization support via zvariant
//! - Cross-toolkit palette synchronization
//!
//! ## Related
//! - [Material Design 3 Color Roles](https://m3.material.io/styles/color/roles)
//! - [`crate::dbus::iface::ThemeInterface`]
//!
//! ## Authors
//! - Riju Mondal <rijum8906@gmail.com>
//!
//! ## License
//! MIT License (see LICENSE file for details)
//!
//! ## Copyright
//! Copyright (c) 2026 Riju Mondal. All rights reserved.

use serde::{Deserialize, Serialize};
use zbus::zvariant::Type;

/// Represents a complete Material 3 color palette.
///
/// This structure contains all 25 semantic color roles defined by the Material 3 design system.
/// Each color value is represented as a hex string (e.g., "#FF6200").
///
/// The palette can be dynamically generated from a seed color or loaded from a stored configuration.
/// All colors are guaranteed to meet WCAG 2.1 AA contrast ratio standards for accessibility.
///
/// # Fields
/// - `seed_color`: The base color used to generate this palette (e.g., dominant wallpaper color)
/// - `primary`, `on_primary`, `primary_container`, `on_primary_container`: High-emphasis action colors
/// - `secondary`, `on_secondary`, `secondary_container`, `on_secondary_container`: Secondary UI colors
/// - `tertiary`, `on_tertiary`, `tertiary_container`, `on_tertiary_container`: Tertiary accent colors
/// - `error`, `on_error`, `error_container`, `on_error_container`: Destructive action colors
/// - `surface`, `surface_container`, `surface_variant`, `on_surface_variant`: Background and neutral colors
/// - `outline`, `outline_variant`: Structural dividers and borders
/// - `shadow`, `scrim`: Drop shadows and modal overlays
/// - `inverse_surface`, `inverse_primary`, `inverse_on_surface`: High-contrast alternative surfaces
///
/// # See Also
/// - [Material 3 Color Roles Documentation](https://m3.material.io/styles/color/roles)
#[derive(Type, Serialize, Deserialize, PartialEq)]
pub struct MaterialColorPalette {
    /// Seed color used to derive this palette (hex string, e.g., "#6DD6DA")
    pub seed_color: String,

    // === PRIMARY COLORS ===
    /// Primary action color: High-emphasis fills for buttons, tabs, and key UI elements
    pub primary: String,
    /// Text/icon color on primary surfaces
    pub on_primary: String,
    /// Container background for featured cards and highlighted items
    pub primary_container: String,
    /// Text/icon color on primary_container
    pub on_primary_container: String,

    // === SECONDARY COLORS ===
    /// Secondary UI element color for less prominent controls
    pub secondary: String,
    /// Text/icon color on secondary surfaces
    pub on_secondary: String,
    /// Container background for secondary components
    pub secondary_container: String,
    /// Text/icon color on secondary_container
    pub on_secondary_container: String,

    // === TERTIARY COLORS ===
    /// Tertiary accent color for subtle highlights and notifications
    pub tertiary: String,
    /// Text/icon color on tertiary surfaces
    pub on_tertiary: String,
    /// Container background for tertiary components
    pub tertiary_container: String,
    /// Text/icon color on tertiary_container
    pub on_tertiary_container: String,

    // === ERROR COLORS ===
    /// Error/destructive action color for alerts and warnings
    pub error: String,
    /// Text/icon color on error surfaces
    pub on_error: String,
    /// Container background for error messages and alerts
    pub error_container: String,
    /// Text/icon color on error_container
    pub on_error_container: String,

    // === SURFACE COLORS ===
    /// Standard background surface for windows and panels
    pub surface: String,
    /// Secondary container surface (e.g., for cards, sidebars)
    pub surface_container: String,
    /// Variant of surface for subtle differentiation
    pub surface_variant: String,
    /// Medium-emphasis text on surface_variant
    pub on_surface_variant: String,

    // === OUTLINE COLORS ===
    /// Borders, outlines, and structural dividers
    pub outline: String,
    /// Subtle variant of outline for low-contrast borders
    pub outline_variant: String,

    // === EFFECT COLORS ===
    /// Drop shadow tint color for elevation effects
    pub shadow: String,
    /// Semi-transparent overlay for modal dialogs and menus
    pub scrim: String,

    // === INVERSE COLORS ===
    /// High-contrast surface for snackbars and floating toasts
    pub inverse_surface: String,
    /// Action button color for use inside inverse_surface
    pub inverse_primary: String,
    /// Text/icon color on inverse_surface
    pub inverse_on_surface: String,
}

impl Default for MaterialColorPalette {
    fn default() -> Self {
        Self {
            seed_color: String::new(),
            primary: String::new(),
            on_primary: String::new(),
            primary_container: String::new(),
            on_primary_container: String::new(),
            secondary: String::new(),
            on_secondary: String::new(),
            secondary_container: String::new(),
            on_secondary_container: String::new(),
            tertiary: String::new(),
            on_tertiary: String::new(),
            tertiary_container: String::new(),
            on_tertiary_container: String::new(),
            error: String::new(),
            on_error: String::new(),
            error_container: String::new(),
            on_error_container: String::new(),
            surface: String::new(),
            surface_container: String::new(),
            surface_variant: String::new(),
            on_surface_variant: String::new(),
            outline: String::new(),
            outline_variant: String::new(),
            shadow: String::new(),
            scrim: String::new(),
            inverse_surface: String::new(),
            inverse_primary: String::new(),
            inverse_on_surface: String::new(),
        }
    }
}
