/// # Desktop Application
///
/// Domain representation of an installed application that can be launched from
/// a Linux desktop entry.
class DesktopApplication {
  /// Creates an installed desktop application.
  const DesktopApplication({
    required this.id,
    required this.name,
    required this.desktopFile,
    this.description = '',
    this.iconName = '',
    this.iconPath,
    this.categories = const [],
  });

  /// Desktop-file ID used by `gtk-launch`.
  final String id;

  /// User-facing application name.
  final String name;

  /// Absolute path of the source `.desktop` file.
  final String desktopFile;

  /// Optional user-facing summary from the desktop entry.
  final String description;

  /// Icon name or path declared by the desktop entry.
  final String iconName;

  /// Resolved icon file path, when one was found on the system.
  final String? iconPath;

  /// Categories declared by the desktop entry.
  final List<String> categories;

  /// Friendly label for the application's primary desktop category.
  ///
  /// Desktop entries list multiple freedesktop categories; the first one with
  /// a known display label is shown in the launcher so users can scan results
  /// by kind without reading the whole entry.
  String get categoryLabel {
    for (final category in categories) {
      final label = _categoryLabels[category];
      if (label != null) {
        return label;
      }
    }
    return '';
  }

  /// Maps freedesktop main categories to concise display labels.
  static const Map<String, String> _categoryLabels = {
    'AudioVideo': 'Media',
    'Audio': 'Audio',
    'Video': 'Video',
    'Development': 'Development',
    'Education': 'Education',
    'Game': 'Games',
    'Graphics': 'Graphics',
    'Network': 'Internet',
    'Office': 'Office',
    'Science': 'Science',
    'Settings': 'Settings',
    'System': 'System',
    'Utility': 'Utilities',
  };

  /// Whether [query] matches this application's searchable metadata.
  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return '$name $description ${categories.join(' ')} $id'
        .toLowerCase()
        .contains(normalized);
  }
}
