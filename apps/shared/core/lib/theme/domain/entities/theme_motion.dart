import 'package:core/utils/color_utils.dart';
import 'package:dbus/dbus.dart';

class ThemeMotion {
  const ThemeMotion({
    required this.durationShortMs,
    required this.durationMediumMs,
    required this.durationLongMs,
    required this.curveStandard,
    required this.curveEmphasized,
  });

  final int durationShortMs;
  final int durationMediumMs;
  final int durationLongMs;
  final String curveStandard;
  final String curveEmphasized;

  /// Short micro-interaction duration.
  Duration get short => Duration(milliseconds: durationShortMs);

  /// Medium interaction duration.
  Duration get medium => Duration(milliseconds: durationMediumMs);

  /// Long interaction duration.
  Duration get long => Duration(milliseconds: durationLongMs);

  /// Decodes the `(uuuss)` motion struct.
  factory ThemeMotion.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length != 5) {
      throw const FormatException('motion must expose durations and curves');
    }
    return ThemeMotion(
      durationShortMs: value.children[0].asUint32(),
      durationMediumMs: value.children[1].asUint32(),
      durationLongMs: value.children[2].asUint32(),
      curveStandard: value.children[3].asString(),
      curveEmphasized: value.children[4].asString(),
    );
  }

  /// Decodes the `motion` object of a JSON payload.
  factory ThemeMotion.fromJson(Map<String, dynamic> json) {
    return ThemeMotion(
      durationShortMs: readInt(json['duration_short_ms']),
      durationMediumMs: readInt(json['duration_medium_ms']),
      durationLongMs: readInt(json['duration_long_ms']),
      curveStandard: readString(json['curve_standard']),
      curveEmphasized: readString(json['curve_emphasized']),
    );
  }
}
