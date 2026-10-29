//! # App Theme
//!
//! Material 3 dark theme used by the RDE shell panel.

import 'package:flutter/material.dart';

/// Builds the shell's Material 3 theme.
abstract final class AppTheme {
  /// Seed colour used to generate the shell palette.
  static const Color seedColor = Color(0xFF8E7CF5);

  /// Returns the shell's dark theme.
  static ThemeData dark() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // The panel paints its own surface on a transparent layer surface.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
    );
  }
}
