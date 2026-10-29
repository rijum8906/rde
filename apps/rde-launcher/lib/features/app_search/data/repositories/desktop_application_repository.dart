import 'dart:io';

import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/domain/repositories/application_repository.dart';

/// # Desktop Application Repository
///
/// Discovers XDG application desktop entries and delegates launching to GTK's
/// desktop-entry launcher, preserving desktop-specific launch environment.
class DesktopApplicationRepository implements ApplicationRepository {
  /// Creates the Linux desktop-entry repository.
  const DesktopApplicationRepository();

  @override
  Future<List<DesktopApplication>> loadApplications() async {
    final environment = Platform.environment;
    final dataHome = environment['XDG_DATA_HOME']?.trim();
    final roots = <String>[
      if (dataHome != null && dataHome.isNotEmpty)
        dataHome
      else if ((environment['HOME'] ?? '').isNotEmpty)
        '${environment['HOME']}/.local/share',
      for (final root
          in (environment['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
              .split(':'))
        if (root.isNotEmpty) root,
    ];

    // Step 1: Read each XDG application root in priority order. The first
    // desktop-file ID wins, including hidden entries that mask system copies.
    final entriesById = <String, DesktopApplication>{};
    final maskedIds = <String>{};
    for (final root in roots) {
      final applicationsDirectory = Directory('$root/applications');
      if (!await applicationsDirectory.exists()) {
        continue;
      }

      try {
        await for (final entity in applicationsDirectory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || !entity.path.endsWith('.desktop')) {
            continue;
          }

          final relativePath = entity.path.substring(
            applicationsDirectory.path.length + 1,
          );
          final id = relativePath
              .replaceAll(Platform.pathSeparator, '-')
              .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
          if (entriesById.containsKey(id) || maskedIds.contains(id)) {
            continue;
          }

          final values = await _readDesktopEntry(entity);
          if (values == null) {
            continue;
          }
          if (_isTrue(values['Hidden']) || _isTrue(values['NoDisplay'])) {
            maskedIds.add(id);
            continue;
          }
          if (values['Type'] != null && values['Type'] != 'Application') {
            continue;
          }

          final name = values['Name']?.trim();
          if (name == null || name.isEmpty) {
            continue;
          }

          entriesById[id] = DesktopApplication(
            id: id.replaceFirst(RegExp(r'\.desktop$'), ''),
            name: name,
            desktopFile: entity.path,
            description: values['Comment']?.trim() ?? '',
            iconName: values['Icon']?.trim() ?? '',
            iconPath: _resolveIcon(values['Icon']?.trim() ?? '', roots),
            categories: (values['Categories'] ?? '')
                .split(';')
                .where((category) => category.isNotEmpty)
                .toList(growable: false),
          );
        }
      } on FileSystemException {
        // An unreadable optional application directory should not hide apps in
        // other XDG roots.
        continue;
      }
    }

    return entriesById.values.toList(growable: false);
  }

  @override
  Future<void> launch(DesktopApplication application) async {
    // Step 1: Use the desktop ID, not the Exec string, so GTK applies the
    // desktop-entry rules for field codes, environment, and terminal apps.
    final result = await Process.run('gtk-launch', [application.id]);
    if (result.exitCode != 0) {
      final details = result.stderr.toString().trim();
      throw ProcessException(
        'gtk-launch',
        [application.id],
        details.isEmpty ? 'Application launch failed' : details,
        result.exitCode,
      );
    }
  }

  Future<Map<String, String>?> _readDesktopEntry(File file) async {
    try {
      final lines = await file.readAsLines();
      var inDesktopEntry = false;
      final values = <String, String>{};
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          inDesktopEntry = trimmed == '[Desktop Entry]';
          continue;
        }
        if (!inDesktopEntry || trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        final separator = trimmed.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        final key = trimmed.substring(0, separator);
        // Only unlocalized names are used until locale fallback is required.
        if (!key.contains('[')) {
          values[key] = _unescape(trimmed.substring(separator + 1));
        }
      }
      return values.isEmpty ? null : values;
    } on FileSystemException {
      return null;
    }
  }

  String _unescape(String value) {
    return value
        .replaceAll(r'\s', ' ')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\\', r'\');
  }

  bool _isTrue(String? value) => value?.toLowerCase() == 'true';

  String? _resolveIcon(String icon, List<String> roots) {
    if (icon.isEmpty) {
      return null;
    }

    final candidates = <String>[];
    if (icon.startsWith('/')) {
      candidates.add(icon);
    } else {
      final fileName = icon.contains('.') ? icon : '$icon.png';
      for (final root in roots) {
        for (final theme in ['hicolor', 'Adwaita']) {
          for (final size in [
            'scalable',
            '512x512',
            '256x256',
            '128x128',
            '96x96',
            '64x64',
            '48x48',
            '32x32',
          ]) {
            candidates.add('$root/icons/$theme/$size/apps/$fileName');
          }
        }
        candidates.add('$root/pixmaps/$fileName');
      }
    }

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }
}
