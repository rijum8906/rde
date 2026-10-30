import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/theme.dart';

/// Builds a resolved theme whose roles the mapping assertions can identify.
ResolvedTheme themedResolved(AppearanceMode mode) {
  final hexes = List<String>.filled(ColorRoles.roleCount, '#808080');
  hexes[0] = '#006A6A'; // primary
  hexes[1] = '#FFFFFF'; // on_primary
  hexes[12] = '#BA1A1A'; // error
  hexes[13] = '#FFFFFF'; // on_error
  hexes[18] = mode.isDark ? '#0E1414' : '#FAFDFC'; // surface
  hexes[19] = mode.isDark ? '#E0E3E2' : '#191C1C'; // on_surface
  hexes[25] = '#E8ECEB'; // surface_container_high
  hexes[27] = '#6F7979'; // outline
  hexes[28] = '#BEC9C8'; // outline_variant

  return ResolvedTheme(
    schemaVersion: 1,
    themeId: 'ocean',
    variant: mode.isDark ? 'dark' : 'light',
    kind: VariantKind.staticFile,
    colors: ColorRoles.fromHexList(hexes),
    typography: const ThemeTypography(fontFamily: 'Inter, Roboto, sans-serif'),
    shape: const ThemeShape(
      radiusExtraSmall: 4,
      radiusSmall: 8,
      radiusMedium: 12,
      radiusLarge: 16,
      radiusExtraLarge: 28,
    ),
    motion: const ThemeMotion(
      durationShortMs: 150,
      durationMediumMs: 300,
      durationLongMs: 500,
      curveStandard: 'cubic-bezier(0.2, 0.0, 0.0, 1.0)',
      curveEmphasized: 'cubic-bezier(0.2, 0.0, 0.0, 1.25)',
    ),
  );
}

void main() {
  group('ThemeColor.parseArgb', () {
    test('accepts #RRGGBB and RRGGBB', () {
      expect(ThemeColor.parseArgb('#006A6A'), 0xFF006A6A);
      expect(ThemeColor.parseArgb('006A6A'), 0xFF006A6A);
      expect(ThemeColor.parseArgb('  #006A6A  '), 0xFF006A6A);
    });

    test('expands #RGB shorthand', () {
      expect(ThemeColor.parseArgb('#0A6'), 0xFF00AA66);
    });

    test('rejects malformed colors', () {
      expect(ThemeColor.parseArgb(''), isNull);
      expect(ThemeColor.parseArgb('#12345'), isNull);
      expect(ThemeColor.parseArgb('#GGGGGG'), isNull);
    });
  });

  group('ThemeColor.tryParse', () {
    test('normalizes accepted colors to uppercase #RRGGBB', () {
      expect(ThemeColor.tryParse('0a6')?.value, '#00AA66');
      expect(ThemeColor.tryParse('#006a6a')?.value, '#006A6A');
      expect(ThemeColor.tryParse('teal'), isNull);
    });
  });

  group('colorSchemeFromResolved', () {
    test('maps the service roles onto a Material 3 scheme', () {
      final scheme = colorSchemeFromResolved(
        themedResolved(AppearanceMode.light),
        mode: AppearanceMode.light,
      );

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, const Color(0xFF006A6A));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.surface, const Color(0xFFFAFDFC));
      expect(scheme.onSurface, const Color(0xFF191C1C));
      expect(scheme.surfaceContainerHigh, const Color(0xFFE8ECEB));
      expect(scheme.error, const Color(0xFFBA1A1A));
      expect(scheme.outline, const Color(0xFF6F7979));
      expect(scheme.outlineVariant, const Color(0xFFBEC9C8));
      // The scheme is tinted by the primary role, matching Material 3.
      expect(scheme.surfaceTint, const Color(0xFF006A6A));
    });

    test('reports dark brightness for dark payloads', () {
      final scheme = colorSchemeFromResolved(
        themedResolved(AppearanceMode.dark),
        mode: AppearanceMode.dark,
      );

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, const Color(0xFF0E1414));
      expect(scheme.onSurface, const Color(0xFFE0E3E2));
    });
  });

  group('buildRdeTheme', () {
    test('carries the published typography, shape, and motion tokens', () {
      final theme = buildRdeTheme(
        themedResolved(AppearanceMode.dark),
        mode: AppearanceMode.dark,
      );

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      // Generic CSS families are dropped from the Flutter fallback list.
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, ['Roboto']);
      expect(theme.colorScheme.primary, const Color(0xFF006A6A));
      expect(
        theme.extension<RdeThemeMotion>()?.short,
        const Duration(milliseconds: 150),
      );
    });
  });
}
