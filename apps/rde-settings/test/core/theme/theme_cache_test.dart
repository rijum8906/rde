import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/theme_cache.dart';

/// All color roles in the order the service serializes them.
const List<String> _roleKeys = [
  'primary',
  'on_primary',
  'primary_container',
  'on_primary_container',
  'secondary',
  'on_secondary',
  'secondary_container',
  'on_secondary_container',
  'tertiary',
  'on_tertiary',
  'tertiary_container',
  'on_tertiary_container',
  'error',
  'on_error',
  'error_container',
  'on_error_container',
  'background',
  'on_background',
  'surface',
  'on_surface',
  'surface_variant',
  'on_surface_variant',
  'surface_container_lowest',
  'surface_container_low',
  'surface_container',
  'surface_container_high',
  'surface_container_highest',
  'outline',
  'outline_variant',
  'shadow',
  'scrim',
  'inverse_surface',
  'inverse_on_surface',
  'inverse_primary',
];

/// Builds the JSON document the service writes before emitting `ThemeChanged`.
String cachePayload() {
  final colors = {for (final key in _roleKeys) key: '#808080'};
  colors['primary'] = '#006A6A';
  colors['surface'] = '#0E1414';
  colors['on_surface'] = '#E0E3E2';

  return jsonEncode({
    'schema_version': 1,
    'theme_id': 'ocean',
    'variant': 'dark',
    'kind': 'static',
    'colors': colors,
    'typography': {
      'font_family': 'Inter, sans-serif',
      'mono_family': 'JetBrains Mono',
    },
    'shape': {
      'radius_extra_small': 4.0,
      'radius_small': 8.0,
      'radius_medium': 12.0,
      'radius_large': 16.0,
      'radius_extra_large': 28.0,
    },
    'motion': {
      'duration_short_ms': 150,
      'duration_medium_ms': 300,
      'duration_long_ms': 500,
      'curve_standard': 'cubic-bezier(0.2, 0.0, 0.0, 1.0)',
      'curve_emphasized': 'cubic-bezier(0.2, 0.0, 0.0, 1.25)',
    },
    'assets': {'wallpaper': '/home/user/wallpaper.png'},
  });
}

void main() {
  late Directory directory;

  setUp(
    () => directory = Directory.systemTemp.createTempSync('rde-theme-cache'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  test('default path matches the file the service publishes', () {
    expect(
      RdeThemeCache.defaultPath,
      endsWith('/rde/rde-theme/default_theme.json'),
    );
  });

  test('reads the resolved theme the service cached', () {
    final file = File('${directory.path}/default_theme.json')
      ..writeAsStringSync(cachePayload());

    final resolved = RdeThemeCache(path: file.path).read();

    expect(resolved, isNotNull);
    expect(resolved?.themeId, 'ocean');
    expect(resolved?.variant, 'dark');
    expect(resolved?.kind, VariantKind.staticFile);
    expect(resolved?.colors.primary.value, '#006A6A');
    expect(resolved?.colors.surface.value, '#0E1414');
    expect(resolved?.typography.families, ['Inter']);
    expect(resolved?.typography.monoFamily, 'JetBrains Mono');
    expect(resolved?.shape.radiusExtraLarge, 28.0);
    expect(resolved?.motion.short, const Duration(milliseconds: 150));
    expect(resolved?.assets.wallpaper, '/home/user/wallpaper.png');
  });

  test('returns null when the service has not published yet', () {
    final file = File('${directory.path}/default_theme.json');

    expect(RdeThemeCache(path: file.path).read(), isNull);
  });

  test('ignores a malformed cache payload', () {
    final file = File('${directory.path}/default_theme.json')
      ..writeAsStringSync('{"schema_version": 1}');

    expect(RdeThemeCache(path: file.path).read(), isNull);
  });
}
