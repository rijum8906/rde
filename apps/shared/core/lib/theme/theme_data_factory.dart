import 'package:core/theme/domain/entities/appearance_mode.dart';
import 'package:core/theme/domain/entities/resolved_theme.dart';
import 'package:core/theme/domain/entities/theme_color.dart';
import 'package:flutter/material.dart';

/// Builds an RDE application's [ThemeData] from the resolved desktop theme.
///
/// Colors, font stack, corner radii, and motion tokens all come from the
/// payload published by `org.rde.Theme`, keeping themed applications aligned.
///
/// # Parameters
/// - [resolved]: payload returned by `GetResolvedTheme`, `Preview`, or the
///   `ThemeChanged` signal
/// - [mode]: appearance the payload was resolved for; the payload carries no
///   brightness of its own
ThemeData buildRdeTheme(
  ResolvedTheme resolved, {
  required AppearanceMode mode,
}) {
  final scheme = colorSchemeFromResolved(resolved, mode: mode);
  final shape = resolved.shape;
  final families = resolved.typography.families;
  final isDark = mode.isDark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: families.first,
    fontFamilyFallback: families.skip(1).toList(),
    scaffoldBackgroundColor: scheme.surface,
    extensions: [RdeThemeMotion.fromThemeMotion(resolved.motion)],
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shape.radiusLarge),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shape.radiusExtraLarge),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onPrimary;
        }
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return scheme.surfaceContainerHighest;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.secondaryContainer,
      thumbColor: scheme.primary,
      trackHeight: 6,
      valueIndicatorColor: scheme.primary,
      valueIndicatorTextStyle: TextStyle(color: scheme.onPrimary),
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shape.radiusMedium),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shape.radiusMedium),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(shape.radiusMedium),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shape.radiusMedium),
      ),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
  );
}

/// Maps the role set of a resolved theme onto a Material 3 [ColorScheme].
///
/// # Parameters
/// - [resolved]: payload whose color roles are mapped
/// - [mode]: appearance the payload was resolved for
ColorScheme colorSchemeFromResolved(
  ResolvedTheme resolved, {
  required AppearanceMode mode,
}) {
  final colors = resolved.colors;

  Color of(ThemeColor color) => color.toColor();

  return ColorScheme(
    brightness: mode.isDark ? Brightness.dark : Brightness.light,
    primary: of(colors.primary),
    onPrimary: of(colors.onPrimary),
    primaryContainer: of(colors.primaryContainer),
    onPrimaryContainer: of(colors.onPrimaryContainer),
    secondary: of(colors.secondary),
    onSecondary: of(colors.onSecondary),
    secondaryContainer: of(colors.secondaryContainer),
    onSecondaryContainer: of(colors.onSecondaryContainer),
    tertiary: of(colors.tertiary),
    onTertiary: of(colors.onTertiary),
    tertiaryContainer: of(colors.tertiaryContainer),
    onTertiaryContainer: of(colors.onTertiaryContainer),
    error: of(colors.error),
    onError: of(colors.onError),
    errorContainer: of(colors.errorContainer),
    onErrorContainer: of(colors.onErrorContainer),
    surface: of(colors.surface),
    onSurface: of(colors.onSurface),
    surfaceDim: of(colors.surfaceContainerLow),
    surfaceBright: of(colors.surfaceContainerHigh),
    surfaceContainerLowest: of(colors.surfaceContainerLowest),
    surfaceContainerLow: of(colors.surfaceContainerLow),
    surfaceContainer: of(colors.surfaceContainer),
    surfaceContainerHigh: of(colors.surfaceContainerHigh),
    surfaceContainerHighest: of(colors.surfaceContainerHighest),
    onSurfaceVariant: of(colors.onSurfaceVariant),
    outline: of(colors.outline),
    outlineVariant: of(colors.outlineVariant),
    shadow: of(colors.shadow),
    scrim: of(colors.scrim),
    inverseSurface: of(colors.inverseSurface),
    onInverseSurface: of(colors.inverseOnSurface),
    inversePrimary: of(colors.inversePrimary),
    surfaceTint: of(colors.primary),
  );
}

/// Motion tokens published by the desktop theme.
///
/// Exposed as a [ThemeExtension] so widgets animate with the durations and
/// curves the theme author chose instead of hard-coded values.
class RdeThemeMotion extends ThemeExtension<RdeThemeMotion> {
  const RdeThemeMotion({
    required this.short,
    required this.medium,
    required this.long,
    required this.standard,
    required this.emphasized,
  });

  /// Durations used when a theme payload is missing or unreadable.
  static const RdeThemeMotion fallback = RdeThemeMotion(
    short: Duration(milliseconds: 150),
    medium: Duration(milliseconds: 300),
    long: Duration(milliseconds: 500),
    standard: Curves.easeOutCubic,
    emphasized: Curves.easeOutCubic,
  );

  /// Micro-interaction duration.
  final Duration short;

  /// Standard interaction duration.
  final Duration medium;

  /// Long transition duration.
  final Duration long;

  /// Curve used by standard transitions.
  final Curve standard;

  /// Curve used by emphasized transitions.
  final Curve emphasized;

  /// Returns the motion tokens of the enclosing theme.
  static RdeThemeMotion of(BuildContext context) {
    return Theme.of(context).extension<RdeThemeMotion>() ?? fallback;
  }

  /// Builds the extension from the resolved payload of the desktop theme.
  factory RdeThemeMotion.fromThemeMotion(ThemeMotion motion) {
    return RdeThemeMotion(
      short: motion.short,
      medium: motion.medium,
      long: motion.long,
      standard: parseCurve(motion.curveStandard) ?? fallback.standard,
      emphasized: parseCurve(motion.curveEmphasized) ?? fallback.emphasized,
    );
  }

  /// Parses a CSS `cubic-bezier(x1, y1, x2, y2)` curve.
  ///
  /// # Returns
  /// The matching [Cubic], or `null` when the value is not a valid bezier.
  static Curve? parseCurve(String value) {
    final match = RegExp(r'cubic-bezier\(([^)]*)\)').firstMatch(value);
    if (match == null) {
      return null;
    }

    final parts = match
        .group(1)!
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return null;
    }

    // Cubic requires the x control points to stay inside the unit interval.
    final x1 = parts[0]!.clamp(0.0, 1.0);
    final y1 = parts[1]!;
    final x2 = parts[2]!.clamp(0.0, 1.0);
    final y2 = parts[3]!;
    return Cubic(x1, y1, x2, y2);
  }

  @override
  RdeThemeMotion copyWith({
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? standard,
    Curve? emphasized,
  }) {
    return RdeThemeMotion(
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
      standard: standard ?? this.standard,
      emphasized: emphasized ?? this.emphasized,
    );
  }

  @override
  RdeThemeMotion lerp(ThemeExtension<RdeThemeMotion>? other, double t) {
    if (other is! RdeThemeMotion) {
      return this;
    }

    // Curves cannot be interpolated; switch at the midpoint instead.
    return t < 0.5 ? this : other;
  }
}
