import 'package:core/theme.dart';

/// Builds a resolved payload with the given primary color and appearance.
///
/// The role order matches the service's `ColorRoles` struct; only the roles the
/// settings UI reads are given meaningful values.
ResolvedTheme sampleResolvedTheme({
  required String themeId,
  required String primary,
  required AppearanceMode mode,
}) {
  final hexes = List<String>.filled(ColorRoles.roleCount, '#808080');
  hexes[0] = primary;
  hexes[1] = '#FFFFFF';
  hexes[18] = mode.isDark ? '#101413' : '#FAFDFC';
  hexes[19] = mode.isDark ? '#E0E3E2' : '#191C1C';
  hexes[25] = mode.isDark ? '#1A1F1E' : '#E8ECEB';

  return ResolvedTheme(
    schemaVersion: 1,
    themeId: themeId,
    variant: mode.isDark ? 'dark' : 'light',
    kind: VariantKind.staticFile,
    colors: ColorRoles.fromHexList(hexes),
    typography: const ThemeTypography(
      fontFamily: 'Cantarell, Inter, sans-serif',
    ),
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
