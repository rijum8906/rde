import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_snapshot.dart';

/// Complete theme state the settings UI renders from.
///
/// Combines the service properties, the author manifest of every installed
/// theme, and the resolved payload the desktop currently renders, so the UI can
/// switch themes, edit the dynamic seed inputs, and preview appearances without
/// extra D-Bus calls.
class ThemeCatalog {
  const ThemeCatalog({
    required this.snapshot,
    required this.themes,
    required this.resolved,
  });

  /// Service properties the catalog was built from.
  final ThemeSnapshot snapshot;

  /// Author manifests of every theme the picker offers, including the built-in
  /// dynamic theme.
  final List<ThemeManifest> themes;

  /// Payload the desktop currently renders.
  final ResolvedTheme resolved;

  /// Identifier of the active theme, resolving `rde-dynamic` for the built-in
  /// theme.
  String get currentTheme => snapshot.activeThemeId;

  /// Appearance the desktop currently renders.
  AppearanceMode get mode => snapshot.mode;

  /// Whether the built-in dynamic theme is active.
  bool get isDynamicActive => currentTheme == ThemeManifest.dynamicId;

  /// Manifest of the active theme, or `null` when it disappeared between calls.
  ThemeManifest? get activeTheme => themeById(currentTheme);

  /// Returns the manifest of [id], or `null` when the theme is unknown.
  ThemeManifest? themeById(String id) {
    for (final theme in themes) {
      if (theme.name == id) {
        return theme;
      }
    }
    return null;
  }
}
