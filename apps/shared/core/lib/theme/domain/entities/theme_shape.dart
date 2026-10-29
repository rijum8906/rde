import 'package:dbus/dbus.dart';
import 'package:core/utils/color_utils.dart';

class ThemeShape {
  const ThemeShape({
    required this.radiusExtraSmall,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusExtraLarge,
  });

  final double radiusExtraSmall;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusExtraLarge;

  /// Decodes the `(ddddd)` shape struct.
  factory ThemeShape.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length != 5) {
      throw const FormatException('shape must expose five radius tokens');
    }
    return ThemeShape(
      radiusExtraSmall: value.children[0].asDouble(),
      radiusSmall: value.children[1].asDouble(),
      radiusMedium: value.children[2].asDouble(),
      radiusLarge: value.children[3].asDouble(),
      radiusExtraLarge: value.children[4].asDouble(),
    );
  }

  /// Decodes the `shape` object of a JSON payload.
  factory ThemeShape.fromJson(Map<String, dynamic> json) {
    return ThemeShape(
      radiusExtraSmall: readDouble(json['radius_extra_small']),
      radiusSmall: readDouble(json['radius_small']),
      radiusMedium: readDouble(json['radius_medium']),
      radiusLarge: readDouble(json['radius_large']),
      radiusExtraLarge: readDouble(json['radius_extra_large']),
    );
  }
}
