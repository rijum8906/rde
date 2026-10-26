import 'package:flutter/material.dart';

/// A color role published by the `org.rde.Theme` service.
///
/// The service always sends canonical `#RRGGBB` strings, but pickers need to
/// accept the `#RGB` shorthand and a missing leading hash, so
/// [ThemeColor.tryParse] applies one set of rules to both sources.
class ThemeColor {
  /// Creates a color from an already normalized `#RRGGBB` string.
  const ThemeColor(this.value);

  /// Normalized `#RRGGBB` representation of the color.
  final String value;

  /// Packed ARGB value understood by Flutter.
  int get argb => parseArgb(value) ?? _fallbackArgb;

  /// Flutter color for this role.
  Color toColor() => Color(argb);

  /// Seed used when a malformed value slipped past validation.
  static const int _fallbackArgb = 0xFF6750A4;

  /// Parses [input] as packed ARGB.
  ///
  /// # Parameters
  /// - [input]: `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB`
  ///
  /// # Returns
  /// The opaque ARGB value, or `null` when the input is not a valid color.
  static int? parseArgb(String input) {
    // Step 1: Normalize the input by dropping an optional leading hash.
    var hex = input.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    // Step 2: Expand the three-digit shorthand into six digits.
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }

    // Step 3: Only six-digit colors are accepted.
    if (hex.length != 6) {
      return null;
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }

    // Step 4: Pack the color as fully opaque ARGB.
    return 0xFF000000 | parsed;
  }

  /// Parses [input] into a normalized [ThemeColor].
  ///
  /// # Returns
  /// The color with its value rewritten as uppercase `#RRGGBB`, or `null` when
  /// the input is not a valid color.
  static ThemeColor? tryParse(String input) {
    final argb = parseArgb(input);
    if (argb == null) {
      return null;
    }
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return ThemeColor('#${rgb.toUpperCase()}');
  }
}
