/// Manifest metadata of an installed theme, as returned by
/// `org.rde.Theme.GetThemeInfo`.
///
/// Palettes are generated from [sourceColor] by the service, so this entity
/// only carries descriptive information for theme pickers.
class RdeThemeInfo {
  const RdeThemeInfo({
    required this.name,
    required this.displayName,
    required this.description,
    required this.sourceColor,
    this.author = '',
    this.license = '',
    this.version = '',
    this.manifestPath = '',
  });

  /// Identifier of the theme, also the directory name under `themes/`.
  final String name;

  /// Human-readable name shown in the picker.
  final String displayName;

  /// Longer description of the theme.
  final String description;

  /// Seed color the service derives every palette from, in `#RRGGBB` form.
  final String sourceColor;

  /// Manifest author, empty when the manifest omits it.
  final String author;

  /// License identifier, empty when the manifest omits it.
  final String license;

  /// Manifest version string, empty when unavailable.
  final String version;

  /// Absolute path of the manifest file, useful for diagnostics.
  final String manifestPath;

  /// Parses the `a{ss}` map returned by `GetThemeInfo`.
  ///
  /// # Parameters
  /// - [info]: decoded D-Bus string map
  ///
  /// # Returns
  /// The parsed metadata, or `null` when the mandatory `name` field is missing.
  static RdeThemeInfo? fromMap(Map<String, String> info) {
    // Step 1: The identifier is the only field the client cannot infer.
    final name = info['name'];
    if (name == null || name.isEmpty) {
      return null;
    }

    // Step 2: Fill in optional metadata with empty defaults so the UI never
    // has to deal with missing keys.
    return RdeThemeInfo(
      name: name,
      displayName: _orFallback(info['display_name'], name),
      description: info['description'] ?? '',
      sourceColor: info['source_color'] ?? '',
      author: info['author'] ?? '',
      license: info['license'] ?? '',
      version: info['version'] ?? '',
      manifestPath: info['manifest_path'] ?? '',
    );
  }

  static String _orFallback(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }
    return value;
  }
}
