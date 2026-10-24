import 'package:flutter/material.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';

/// Fallback seed used when the service omits a role the UI needs.
const Color _fallbackSeed = Color(0xFF6750A4);

/// Converts an `org.rde.Theme` palette into a Flutter [ColorScheme].
///
/// The service generates the same Material 3 roles Flutter exposes, so the
/// settings app can render the desktop palette instead of deriving a local one
/// from a seed color. Missing roles fall back to their closest relative and
/// finally to the Material default, which keeps a partially populated map
/// usable.
extension ThemePaletteMapper on RdePalette {
  /// Builds the [ColorScheme] for this palette.
  ColorScheme toColorScheme() {
    // Step 1: Resolve one role, walking a fallback chain before giving up.
    Color role(String name, [String? fallbackName]) {
      final value =
          argb(name) ?? (fallbackName == null ? null : argb(fallbackName));
      return Color(value ?? _fallbackSeed.toARGB32());
    }

    // Step 2: Map every Material 3 role the settings UI consumes.
    return ColorScheme(
      brightness: scheme.isDark ? Brightness.dark : Brightness.light,
      primary: role('primary'),
      onPrimary: role('on_primary', 'surface'),
      primaryContainer: role('primary_container', 'primary'),
      onPrimaryContainer: role('on_primary_container', 'on_primary'),
      secondary: role('secondary', 'primary'),
      onSecondary: role('on_secondary', 'on_primary'),
      secondaryContainer: role('secondary_container', 'secondary'),
      onSecondaryContainer: role('on_secondary_container', 'on_secondary'),
      tertiary: role('tertiary', 'secondary'),
      onTertiary: role('on_tertiary', 'on_secondary'),
      tertiaryContainer: role('tertiary_container', 'tertiary'),
      onTertiaryContainer: role('on_tertiary_container', 'on_tertiary'),
      error: role('error'),
      onError: role('on_error', 'surface'),
      errorContainer: role('error_container', 'error'),
      onErrorContainer: role('on_error_container', 'on_error'),
      surface: role('surface', 'background'),
      onSurface: role('on_surface', 'on_background'),
      surfaceDim: role('surface_dim', 'surface'),
      surfaceBright: role('surface_bright', 'surface'),
      surfaceContainerLowest: role('surface_container_lowest', 'surface'),
      surfaceContainerLow: role('surface_container_low', 'surface'),
      surfaceContainer: role('surface_container', 'surface'),
      surfaceContainerHigh: role('surface_container_high', 'surface'),
      surfaceContainerHighest: role('surface_container_highest', 'surface'),
      onSurfaceVariant: role('on_surface_variant', 'on_surface'),
      outline: role('outline', 'on_surface_variant'),
      outlineVariant: role('outline_variant', 'outline'),
      shadow: role('shadow'),
      scrim: role('scrim'),
      inverseSurface: role('inverse_surface', 'surface'),
      onInverseSurface: role('inverse_on_surface', 'on_surface'),
      inversePrimary: role('inverse_primary', 'primary'),
      surfaceTint: role('surface_tint', 'primary'),
    );
  }
}
