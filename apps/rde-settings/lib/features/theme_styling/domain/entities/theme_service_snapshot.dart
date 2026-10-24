import 'rde_color_scheme.dart';

/// Read-only state of the `org.rde.Theme` service.
///
/// Mirrors the properties exposed on `/org/rde/Theme` so the data layer can
/// read them in a single `Properties.GetAll` round trip.
class ThemeServiceSnapshot {
  const ThemeServiceSnapshot({
    required this.version,
    required this.currentTheme,
    required this.installedThemes,
    required this.colorScheme,
    required this.sourceColor,
  });

  /// Version of the running theme service.
  final String version;

  /// Identifier of the active theme.
  final String currentTheme;

  /// Identifiers of every installed theme, sorted by the service.
  final List<String> installedThemes;

  /// Active light/dark appearance of the desktop.
  final RdeColorScheme colorScheme;

  /// Source color of the active theme in `#RRGGBB` form.
  final String sourceColor;
}
