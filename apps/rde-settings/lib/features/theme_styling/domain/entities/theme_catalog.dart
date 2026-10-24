import 'rde_color_scheme.dart';
import 'rde_palette.dart';
import 'rde_theme_info.dart';
import 'theme_service_snapshot.dart';

/// Complete theme state the settings UI renders from.
///
/// Combines the service properties, the manifest metadata of every installed
/// theme, and both palettes of the active theme, so the UI can switch between
/// theme pickers, seed colors, and scheme previews without extra D-Bus calls.
class ThemeCatalog {
  const ThemeCatalog({
    required this.snapshot,
    required this.themes,
    required this.lightPalette,
    required this.darkPalette,
  });

  /// Service properties the catalog was built from.
  final ThemeServiceSnapshot snapshot;

  /// Metadata of every installed theme, ordered like
  /// [ThemeServiceSnapshot.installedThemes].
  final List<RdeThemeInfo> themes;

  /// Palette of the active theme in light appearance.
  final RdePalette lightPalette;

  /// Palette of the active theme in dark appearance.
  final RdePalette darkPalette;

  /// Identifier of the active theme.
  String get currentTheme => snapshot.currentTheme;

  /// Active scheme of the desktop.
  RdeColorScheme get colorScheme => snapshot.colorScheme;

  /// Source color of the active theme in `#RRGGBB` form.
  String get sourceColor => snapshot.sourceColor;

  /// Metadata of the active theme, or `null` when the manifest disappeared
  /// between calls.
  RdeThemeInfo? get activeTheme {
    for (final theme in themes) {
      if (theme.name == snapshot.currentTheme) {
        return theme;
      }
    }
    return null;
  }

  /// Returns the palette of the active theme for [scheme].
  RdePalette paletteFor(RdeColorScheme scheme) {
    return scheme.isDark ? darkPalette : lightPalette;
  }
}
