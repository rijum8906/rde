import 'appearance_mode.dart';
import 'theme_manifest.dart';

/// Read-only state of the `org.rde.Theme` service.
///
/// Mirrors the properties exposed on `/org/rde/Theme` so the data layer can
/// read them in a single `Properties.GetAll` round trip. The dynamic seeds are
/// write-only through `UpdateDynamicTheme`, so they are not part of the snapshot.
class ThemeSnapshot {
  const ThemeSnapshot({
    required this.version,
    required this.activeTheme,
    required this.mode,
    required this.availableThemes,
    required this.generation,
  });

  /// Interface contract version.
  final int version;

  /// Identifier of the active theme, empty when the built-in dynamic theme is
  /// active.
  final String activeTheme;

  /// Appearance the desktop currently renders.
  final AppearanceMode mode;

  /// Identifiers of every theme in the registry.
  final List<String> availableThemes;

  /// Monotonically increasing generation of the published payload.
  final int generation;

  /// Identifier of the active theme, resolving the empty string to the
  /// built-in dynamic theme.
  String get activeThemeId =>
      activeTheme.trim().isEmpty ? ThemeManifest.dynamicId : activeTheme.trim();
}
