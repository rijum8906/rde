import 'dart:convert';
import 'dart:io';

import 'package:core/theme/domain/entities/resolved_theme.dart';
import 'package:flutter/foundation.dart';

/// Reads the resolved theme published by `org.rde.Theme` on disk.
///
/// The service writes [fileName] atomically before emitting `ThemeChanged`, so
/// the settings app can adopt the current desktop theme in `main()` without
/// waiting for the session bus. The payload is the same JSON document the
/// service returns from `GetResolvedTheme`; the appearance is not part of it and
/// must be inferred from the surface color.
class RdeThemeCache {
  /// Creates a cache reader, optionally pointed at a non-default [path].
  const RdeThemeCache({this.path});

  /// File name of the published resolved theme cache.
  ///
  /// Must match `DEFAULT_PUBLISHED_THEME_FILE` in the `rde-theme` service.
  static const String fileName = 'default_theme.json';

  /// Path override used by tests; production code uses [defaultPath].
  final String? path;

  /// Default location written by the theme service.
  ///
  /// Resolves `$XDG_DATA_HOME/rde/rde-theme/default_theme.json`, falling back
  /// to `~/.local/share/rde/rde-theme/default_theme.json`.
  static String get defaultPath {
    final environment = Platform.environment;
    final dataHome = environment['XDG_DATA_HOME']?.trim();
    final base = (dataHome != null && dataHome.isNotEmpty)
        ? dataHome
        : '${environment['HOME'] ?? ''}/.local/share';

    return '$base/rde/rde-theme/$fileName';
  }

  /// Reads the cached theme payload.
  ///
  /// # Returns
  /// The decoded theme, or `null` when the file does not exist yet, cannot be
  /// read, or carries a malformed payload.
  ResolvedTheme? read() {
    final target = path ?? defaultPath;

    try {
      // Step 1: A missing cache is expected before the service ran once.
      final file = File(target);
      if (!file.existsSync()) {
        return null;
      }

      // Step 2: Decode the same JSON shape `GetResolvedTheme` serializes.
      final source = file.readAsStringSync();
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'Ignoring the theme cache at $target: unexpected JSON shape',
        );
        return null;
      }
      return ResolvedTheme.fromJson(decoded);
    } on FileSystemException catch (error) {
      debugPrint('Unable to read the theme cache at $target: ${error.message}');
      return null;
    } on FormatException catch (error) {
      debugPrint('Ignoring the theme cache at $target: ${error.message}');
      return null;
    }
  }
}
