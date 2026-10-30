export 'package:core/theme/domain/entities/theme_color_roles.dart'
    show ColorRoles, ThemeColorRoles;
export 'package:core/theme/domain/entities/theme_motion.dart';
export 'package:core/theme/domain/entities/theme_shape.dart';
export 'package:core/theme/domain/entities/theme_typography.dart';

import 'dart:convert';

import 'package:core/theme/domain/entities/theme_color_roles.dart';
import 'package:core/theme/domain/entities/theme_motion.dart';
import 'package:core/theme/domain/entities/theme_shape.dart';
import 'package:core/theme/domain/entities/theme_typography.dart';
import 'package:core/utils/color_utils.dart';
import 'package:dbus/dbus.dart';

class ResolvedTheme {
  const ResolvedTheme({
    required this.schemaVersion,
    required this.themeId,
    required this.variant,
    required this.kind,
    required this.colors,
    required this.typography,
    required this.shape,
    required this.motion,
  });

  /// Payload schema version written by the service.
  final int schemaVersion;

  /// Identifier of the theme that produced this payload.
  final String themeId;

  /// Variant selected from the theme.
  final String variant;

  /// Whether the variant was shipped or computed at runtime.
  final VariantKind kind;

  /// Complete set of Material 3 semantic color roles.
  final ThemeColorRoles colors;

  /// Font families of the desktop theme.
  final ThemeTypography typography;

  /// Corner radius tokens of the desktop theme.
  final ThemeShape shape;

  /// Animation durations and curves of the desktop theme.
  final ThemeMotion motion;

  /// Decodes the struct returned by `GetResolvedTheme`.
  ///
  /// Signature: `(ussu(<colors>)(ss)(ddddd)(uuuss))`.
  ///
  /// # Errors
  /// Throws a [FormatException] when the reply has an unexpected shape.
  factory ResolvedTheme.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length < 8) {
      throw const FormatException('GetResolvedTheme returned an unknown shape');
    }

    final fields = value.children;
    return ResolvedTheme(
      schemaVersion: fields[0].asUint32(),
      themeId: fields[1].asString(),
      variant: fields[2].asString(),
      kind: fields[3].asUint32() == 1
          ? VariantKind.dynamic
          : VariantKind.staticFile,
      colors: ThemeColorRoles.fromDbus(fields[4]),
      typography: ThemeTypography.fromDbus(fields[5]),
      shape: ThemeShape.fromDbus(fields[6]),
      motion: ThemeMotion.fromDbus(fields[7]),
    );
  }

  /// Decodes the serde JSON payload carried by signals and `Preview`.
  ///
  /// # Errors
  /// Throws a [FormatException] when a mandatory field or color is missing.
  factory ResolvedTheme.fromJson(Map<String, dynamic> json) {
    return ResolvedTheme(
      schemaVersion: readInt(json['schema_version']),
      themeId: readString(json['theme_id']),
      variant: readString(json['variant']),
      kind: VariantKind.fromJson(json['kind']),
      colors: ThemeColorRoles.fromJson(readMap(json['colors'])),
      typography: ThemeTypography.fromJson(readMap(json['typography'])),
      shape: ThemeShape.fromJson(readMap(json['shape'])),
      motion: ThemeMotion.fromJson(readMap(json['motion'])),
    );
  }

  /// Parses the JSON string used by the `ThemeChanged` signal.
  ///
  /// # Returns
  /// The decoded theme, or `null` when [source] is not valid theme JSON.
  static ResolvedTheme? tryFromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ResolvedTheme.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

/// Origin of a resolved variant payload.
///
/// Consumers must never branch on this value: shipped variant files and the
/// wallpaper-computed dynamic theme produce exactly the same payload.
enum VariantKind {
  /// Shipped, pre-computed variant file.
  staticFile('static'),

  /// Computed at runtime from the user's wallpaper.
  dynamic('dynamic');

  const VariantKind(this.jsonValue);

  /// Serde representation used when the service sends JSON.
  final String jsonValue;

  /// Maps a JSON value onto the enum, defaulting to [VariantKind.staticFile].
  static VariantKind fromJson(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final kind in VariantKind.values) {
      if (kind.jsonValue == normalized) {
        return kind;
      }
    }
    return VariantKind.staticFile;
  }
}
