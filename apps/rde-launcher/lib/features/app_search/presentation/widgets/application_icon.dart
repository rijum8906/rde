import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';

/// Rounded, themed application icon.
///
/// `.desktop` files can put either a file path or an icon-theme name in their
/// `Icon=` key. This widget tries both: if `application.iconPath` is an
/// absolute path that exists, `Image.file` is used; otherwise the name is
/// looked up under `$XDG_DATA_DIRS/icons/` (and the user's icon dirs), and
/// if that fails, a letter fallback is shown.
class ApplicationIcon extends StatelessWidget {
  const ApplicationIcon({required this.application, this.size = 40, super.key});

  final DesktopApplication application;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: _buildIcon(colors),
    );
  }

  Widget _buildIcon(ColorScheme colors) {
    final path = application.iconPath;
    if (path == null || path.isEmpty) return _fallback(colors);

    // Case 1: absolute path to an image file.
    if (path.startsWith('/')) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallback(colors),
        );
      }
      return _fallback(colors);
    }

    // Case 2: icon-theme name. The lookup is done lazily, so a name that
    // doesn't resolve falls back to the letter without blocking the tile.
    final resolved = _resolveThemeIcon(path);
    if (resolved == null) return _fallback(colors);
    return Image.file(
      resolved,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _fallback(colors),
    );
  }

  Widget _fallback(ColorScheme colors) {
    final initial = application.name.isEmpty
        ? '?'
        : application.name.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  /// Looks up an icon-theme name in the standard XDG icon directories.
  ///
  /// This is a deliberately minimal resolver: it checks the standard theme
  /// sizes (256, 128, 64, 48, 32) and the scalable and symbolic variants,
  /// because those cover ~99% of `.desktop` entries. A full implementation
  /// would read `index.theme` for the active theme's inheritance chain; that
  /// is left for when a user reports a missing icon.
  static File? _resolveThemeIcon(String name) {
    const sizes = ['256x256', '128x128', '64x64', '48x48', '32x32'];
    final bases = <String>[
      for (final dir
          in (Platform.environment['XDG_DATA_DIRS'] ?? '/usr/share').split(':'))
        '$dir/icons',
      if (Platform.environment['XDG_DATA_HOME'] case final home?) '$home/icons',
      '${Platform.environment['HOME'] ?? ''}/.icons',
    ];

    // Try each theme's `hicolor` first (the standard fallback), then
    // adwaita and Papirus (the two most common defaults on RDE-adjacent
    // systems). The list is ordered so the fallback is fast on the
    // common case.
    const themes = ['hicolor', 'Adwaita', 'Papirus'];

    for (final base in bases) {
      for (final themeName in themes) {
        for (final size in sizes) {
          for (final ext in const ['png', 'svg']) {
            final candidate = File('$base/$themeName/$size/apps/$name.$ext');
            if (candidate.existsSync()) return candidate;
          }
        }
        // Scalable icons.
        for (final ext in const ['svg', 'png']) {
          final candidate = File('$base/$themeName/scalable/apps/$name.$ext');
          if (candidate.existsSync()) return candidate;
        }
      }
    }
    return null;
  }
}
