// Material 3 Expressive theme for the RDE shell.
//
// The shell paints on a transparent Wayland layer surface, so the theme keeps
// every default background transparent and lets each widget draw its own
// tonal surface. Colours are generated from a single expressive seed so the
// panel, notification cards, and future shell surfaces stay in sync.

import 'package:flutter/material.dart';

/// Builds the shell's Material 3 Expressive theme.
abstract final class AppTheme {
  /// Seed colour used to generate the expressive palette.
  static const Color seedColor = Color(0xFF8E7CF5);

  /// Font family used across the shell, with graceful fallbacks.
  static const String fontFamily = 'Inter';

  /// Fallback fonts used when Inter is not installed.
  static const List<String> fontFamilyFallback = <String>[
    'Roboto',
    'Segoe UI',
    'Helvetica Neue',
    'sans-serif',
  ];

  /// Returns the shell's dark theme.
  ///
  /// The dark scheme matches a desktop session, and
  /// [DynamicSchemeVariant.expressive] produces the higher-chroma palette used
  /// by Material 3 Expressive instead of the default pastel tones.
  static ThemeData dark() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );

    final ThemeData base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return base.copyWith(
      // The layer surface is transparent; widgets supply their own surfaces.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashColor: colorScheme.primary.withValues(alpha: 0.10),
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      textTheme: base.textTheme.copyWith(
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          height: 1.35,
          letterSpacing: 0.1,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
