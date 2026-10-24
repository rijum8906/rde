import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/presentation/mappers/theme_palette_mapper.dart';

void main() {
  group('RdePalette.parseHexColor', () {
    test('accepts #RRGGBB and RRGGBB', () {
      expect(RdePalette.parseHexColor('#006A6A'), 0xFF006A6A);
      expect(RdePalette.parseHexColor('006A6A'), 0xFF006A6A);
      expect(RdePalette.parseHexColor('  #006A6A  '), 0xFF006A6A);
    });

    test('expands #RGB shorthand', () {
      expect(RdePalette.parseHexColor('#0A6'), 0xFF00AA66);
    });

    test('rejects malformed colors', () {
      expect(RdePalette.parseHexColor(''), isNull);
      expect(RdePalette.parseHexColor('#12345'), isNull);
      expect(RdePalette.parseHexColor('#GGGGGG'), isNull);
    });
  });

  group('RdePalette roles', () {
    test('exposes role hex and packed ARGB values', () {
      const palette = RdePalette(
        theme: 'ocean',
        scheme: RdeColorScheme.dark,
        roles: {'primary': '#A6DCDC', 'surface': '#0E1414'},
      );

      expect(palette.hex('primary'), '#A6DCDC');
      expect(palette.argb('primary'), 0xFFA6DCDC);
      expect(palette.hex('missing'), isNull);
      expect(palette.argb('missing'), isNull);
    });
  });

  group('ThemePaletteMapper', () {
    test('maps service roles onto a Material 3 ColorScheme', () {
      const palette = RdePalette(
        theme: 'ocean',
        scheme: RdeColorScheme.light,
        roles: {
          'primary': '#006A6A',
          'on_primary': '#FFFFFF',
          'primary_container': '#CCE8E9',
          'on_primary_container': '#002021',
          'secondary': '#4A6365',
          'on_secondary': '#FFFFFF',
          'surface': '#FAFDFC',
          'on_surface': '#191C1C',
          'on_surface_variant': '#3F4949',
          'error': '#BA1A1A',
          'on_error': '#FFFFFF',
          'surface_container_high': '#E8ECEB',
          'outline': '#6F7979',
          'outline_variant': '#BEC9C8',
        },
      );

      final scheme = palette.toColorScheme();

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, const Color(0xFF006A6A));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.primaryContainer, const Color(0xFFCCE8E9));
      expect(scheme.secondary, const Color(0xFF4A6365));
      expect(scheme.surface, const Color(0xFFFAFDFC));
      expect(scheme.onSurface, const Color(0xFF191C1C));
      expect(scheme.surfaceContainerHigh, const Color(0xFFE8ECEB));
      expect(scheme.error, const Color(0xFFBA1A1A));
      // surfaceTint falls back to primary when the role is absent.
      expect(scheme.surfaceTint, const Color(0xFF006A6A));
    });

    test('reports dark brightness for dark palettes', () {
      const palette = RdePalette(
        theme: 'ocean',
        scheme: RdeColorScheme.dark,
        roles: {'primary': '#A6DCDC', 'surface': '#0E1414'},
      );

      expect(palette.toColorScheme().brightness, Brightness.dark);
      // A missing onSurface falls back to on_background and then the default.
      expect(palette.toColorScheme().onSurface, const Color(0xFF6750A4));
    });
  });
}
