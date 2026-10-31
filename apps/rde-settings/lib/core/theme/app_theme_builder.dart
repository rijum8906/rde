import 'package:flutter/material.dart';

class AppThemeBuilder {
  const AppThemeBuilder._();

  /// Constructs the Material 3 ThemeData from a given ColorScheme.
  ///
  /// This ensures the app background defaults to `surfaceContainerLowest`
  /// and applies consistent styling to cards, dialogs, inputs, and sliders.
  static ThemeData build(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'Roboto',
        'Segoe UI',
        '-apple-system',
        'Helvetica Neue',
        'sans-serif',
      ],
      // Default app background
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      // Default canvas background (used by some routing/transitions)
      canvasColor: colorScheme.surface,

      cardTheme: CardThemeData(
        elevation: 2,
        color: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 6,
        backgroundColor: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.secondaryContainer,
        thumbColor: colorScheme.primary,
        trackHeight: 6,
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: TextStyle(color: colorScheme.onPrimary),
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
    );
  }
}
