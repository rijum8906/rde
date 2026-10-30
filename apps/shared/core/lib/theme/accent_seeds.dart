import 'package:core/theme/domain/entities/dynamic_seeds.dart';
import 'package:core/theme/domain/entities/theme_color.dart';
import 'package:flutter/material.dart';

/// Material seed used when the picked accent cannot be parsed.
const int _fallbackArgb = 0xFF6750A4;

/// Hue of the Material error family.
const int _errorArgb = 0xFFBA1A1A;

/// Builds the four dynamic seeds from a single accent color.
///
/// The accent becomes the primary seed. Secondary and tertiary rotate its hue
/// by ±60° while keeping its saturation and lightness. Error stays red while
/// borrowing the accent's chroma.
///
/// [accent] accepts any input supported by [ThemeColor.parseArgb].
DynamicSeeds seedsFromAccent(String accent) {
  // Step 1: Fall back to the Material seed when the input is malformed.
  final argb = ThemeColor.parseArgb(accent) ?? _fallbackArgb;
  final base = HSLColor.fromColor(Color(argb));

  // Step 2: Derive supporting families by rotating the accent hue.
  final secondary = _rotateHue(base, 60);
  final tertiary = _rotateHue(base, -60);

  // Step 3: Keep the error family red while following the accent's chroma.
  final error = HSLColor.fromColor(const Color(_errorArgb))
      .withSaturation(base.saturation.clamp(0.6, 1.0).toDouble());

  return DynamicSeeds(
    primary: _hex(base),
    secondary: _hex(secondary),
    tertiary: _hex(tertiary),
    error: _hex(error),
  );
}

/// Rotates [color] by [degrees], wrapping around the color wheel.
HSLColor _rotateHue(HSLColor color, double degrees) {
  final hue = (color.hue + degrees) % 360;
  return color.withHue(hue < 0 ? hue + 360 : hue);
}

/// Formats [color] as the uppercase `#RRGGBB` seed the service accepts.
String _hex(HSLColor color) {
  final rgb = color.toColor().toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
