import 'package:core/theme/domain/entities/appearance_mode.dart';
import 'package:core/theme/domain/entities/resolved_theme.dart';
import 'package:core/theme/spacing.dart';
import 'package:flutter/material.dart';

class RdeThemeBuilder {
  const RdeThemeBuilder._();

  /// Constructs a ThemeData from a dynamically resolved payload.
  static ThemeData fromResolvedTheme(
    ResolvedTheme resolvedTheme,
    AppearanceMode mode,
  ) {
    final isLight = mode == AppearanceMode.light;

    // Step 1: Map every role required by Material 3. Missing roles fall back
    // to their closest semantic equivalent from the resolved payload.
    final colorScheme = ColorScheme(
      brightness: isLight ? Brightness.light : Brightness.dark,

      // Primary
      primary: resolvedTheme.colors.primary.toColor(),
      onPrimary: resolvedTheme.colors.onPrimary.toColor(),
      primaryContainer: resolvedTheme.colors.primaryContainer.toColor(),
      onPrimaryContainer: resolvedTheme.colors.onPrimaryContainer.toColor(),

      // Secondary
      secondary: resolvedTheme.colors.secondary.toColor(),
      onSecondary: resolvedTheme.colors.onSecondary.toColor(),
      secondaryContainer: resolvedTheme.colors.secondaryContainer.toColor(),
      onSecondaryContainer: resolvedTheme.colors.onSecondaryContainer.toColor(),

      // Tertiary
      tertiary: resolvedTheme.colors.tertiary.toColor(),
      onTertiary: resolvedTheme.colors.onTertiary.toColor(),
      tertiaryContainer: resolvedTheme.colors.tertiaryContainer.toColor(),
      onTertiaryContainer: resolvedTheme.colors.onTertiaryContainer.toColor(),

      // Error
      error: resolvedTheme.colors.error.toColor(),
      onError: resolvedTheme.colors.onError.toColor(),
      errorContainer: resolvedTheme.colors.errorContainer.toColor(),
      onErrorContainer: resolvedTheme.colors.onErrorContainer.toColor(),

      // Surfaces
      surface: resolvedTheme.colors.surface.toColor(),
      onSurface: resolvedTheme.colors.onSurface.toColor(),
      surfaceContainerLowest: resolvedTheme.colors.surfaceContainerLowest
          .toColor(),
      surfaceContainerLow: resolvedTheme.colors.surfaceContainerLow.toColor(),
      surfaceContainer: resolvedTheme.colors.surfaceContainer.toColor(),
      surfaceContainerHigh: resolvedTheme.colors.surfaceContainerHigh.toColor(),
      surfaceContainerHighest: resolvedTheme.colors.surfaceContainerHighest
          .toColor(),

      // Outline & Variants
      outline: resolvedTheme.colors.outline.toColor(),
      outlineVariant: resolvedTheme.colors.outlineVariant.toColor(),

      // Inverse (Tooltips/Snackbars)
      inverseSurface: resolvedTheme.colors.inverseSurface.toColor(),
      inversePrimary: resolvedTheme.colors.inversePrimary.toColor(),
    );

    final spacing = Spacing(
      xs: resolvedTheme.shape.radiusExtraSmall,
      sm: resolvedTheme.shape.radiusSmall,
      md: resolvedTheme.shape.radiusMedium,
      lg: resolvedTheme.shape.radiusLarge,
      xl: resolvedTheme.shape.radiusExtraLarge,
    );

    return _base(
      colorScheme: colorScheme,
      fontFamily: resolvedTheme.typography.fontFamily,
      radiusLarge: resolvedTheme.shape.radiusLarge,
      radiusMedium: resolvedTheme.shape.radiusMedium,
      spacing: spacing,
    );
  }

  /// Constructs a ThemeData from a standard ColorScheme (e.g., a local seed).
  static ThemeData build(ColorScheme colorScheme) {
    return _base(
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      radiusLarge: 20.0,
      radiusMedium: 12.0,
    );
  }

  /// The shared base builder used by both dynamic and seed themes.
  static ThemeData _base({
    required ColorScheme colorScheme,
    required String fontFamily,
    required double radiusLarge,
    required double radiusMedium,
    Spacing? spacing,
  }) {
    final s = spacing ?? Spacing();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      fontFamilyFallback: const [
        'Roboto',
        'Segoe UI',
        '-apple-system',
        'Helvetica Neue',
        'sans-serif',
      ],

      // Backgrounds
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      canvasColor: colorScheme.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        actionsPadding: EdgeInsetsGeometry.symmetric(
          vertical: s.md,
          horizontal: s.sm + s.sm,
        ),
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),

      // Cards (Elevation 1)
      cardTheme: CardThemeData(
        elevation: 1,
        color:
            colorScheme.surfaceContainerLow, // Subtle contrast from background
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),

      // Dialogs (Elevation 3)
      dialogTheme: DialogThemeData(
        insetPadding: EdgeInsets.symmetric(
          vertical: s.sm,
          horizontal: s.sm * 2,
        ),
        elevation: 3,
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Sliders
      sliderTheme: SliderThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.secondaryContainer,
        thumbColor: colorScheme.primary,
        trackHeight: 6,
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: TextStyle(color: colorScheme.onPrimary),
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // List Tiles
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),

      // Bottom Sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),
    );
  }
}
