import 'package:dbus/dbus.dart';
import 'package:core/utils/color_utils.dart';

class ThemeTypography {
  const ThemeTypography({required this.fontFamily, this.monoFamily});

  final String fontFamily;
  final String? monoFamily;

  /// Splits [fontFamily] into the concrete family list a Flutter theme accepts.
  ///
  /// Generic CSS families (`sans-serif`, `monospace`, ...) are dropped because
  /// Flutter resolves fonts by family name only.
  List<String> get families {
    const generics = {
      'sans-serif',
      'serif',
      'monospace',
      'system-ui',
      'ui-sans-serif',
      'ui-monospace',
      'cursive',
    };

    final parsed = fontFamily
        .split(',')
        .map((family) => family.trim().replaceAll('"', '').replaceAll("'", ''))
        .where((family) => family.isNotEmpty && !generics.contains(family))
        .toList();

    return parsed.isEmpty ? const ['Inter'] : parsed;
  }

  /// Decodes the `(ss)` typography struct.
  factory ThemeTypography.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length != 2) {
      throw const FormatException('typography must expose a font stack');
    }
    return ThemeTypography(
      fontFamily: value.children[0].asString(),
      monoFamily: optional(value.children[1].asString()),
    );
  }

  /// Decodes the `typography` object of a JSON payload.
  factory ThemeTypography.fromJson(Map<String, dynamic> json) {
    return ThemeTypography(
      fontFamily: readString(json['font_family']),
      monoFamily: optional(json['mono_family']?.toString()),
    );
  }
}
