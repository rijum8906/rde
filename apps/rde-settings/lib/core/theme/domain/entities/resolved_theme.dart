import 'dart:convert';

import 'package:dbus/dbus.dart';

import 'theme_color.dart';

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

/// The fully-resolved theme an application renders.
///
/// This is the interop contract of `org.rde.Theme`: the same payload is
/// returned by `GetResolvedTheme`, carried by the `ThemeChanged` signal, and
/// returned by `Preview`, so a single decoder serves every source.
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
  final ColorRoles colors;

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
      colors: ColorRoles.fromDbus(fields[4]),
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
      schemaVersion: _readInt(json['schema_version']),
      themeId: _readString(json['theme_id']),
      variant: _readString(json['variant']),
      kind: VariantKind.fromJson(json['kind']),
      colors: ColorRoles.fromJson(_readMap(json['colors'])),
      typography: ThemeTypography.fromJson(_readMap(json['typography'])),
      shape: ThemeShape.fromJson(_readMap(json['shape'])),
      motion: ThemeMotion.fromJson(_readMap(json['motion'])),
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

/// Complete set of Material Design 3 semantic color roles.
class ColorRoles {
  const ColorRoles({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.shadow,
    required this.scrim,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.inversePrimary,
  });

  /// Number of roles the service always publishes.
  static const int roleCount = 34;

  final ThemeColor primary;
  final ThemeColor onPrimary;
  final ThemeColor primaryContainer;
  final ThemeColor onPrimaryContainer;
  final ThemeColor secondary;
  final ThemeColor onSecondary;
  final ThemeColor secondaryContainer;
  final ThemeColor onSecondaryContainer;
  final ThemeColor tertiary;
  final ThemeColor onTertiary;
  final ThemeColor tertiaryContainer;
  final ThemeColor onTertiaryContainer;
  final ThemeColor error;
  final ThemeColor onError;
  final ThemeColor errorContainer;
  final ThemeColor onErrorContainer;
  final ThemeColor background;
  final ThemeColor onBackground;
  final ThemeColor surface;
  final ThemeColor onSurface;
  final ThemeColor surfaceVariant;
  final ThemeColor onSurfaceVariant;
  final ThemeColor surfaceContainerLowest;
  final ThemeColor surfaceContainerLow;
  final ThemeColor surfaceContainer;
  final ThemeColor surfaceContainerHigh;
  final ThemeColor surfaceContainerHighest;
  final ThemeColor outline;
  final ThemeColor outlineVariant;
  final ThemeColor shadow;
  final ThemeColor scrim;
  final ThemeColor inverseSurface;
  final ThemeColor inverseOnSurface;
  final ThemeColor inversePrimary;

  /// Decodes the color struct of a resolved theme payload.
  ///
  /// # Errors
  /// Throws a [FormatException] when a role is missing or malformed.
  factory ColorRoles.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length != roleCount) {
      throw const FormatException('resolved colors must expose 34 roles');
    }
    return ColorRoles.fromHexList(
      value.children.map((child) => child.asString()).toList(),
    );
  }

  /// Decodes the `colors` object of a JSON payload.
  ///
  /// # Errors
  /// Throws a [FormatException] when a role is missing or malformed.
  factory ColorRoles.fromJson(Map<String, dynamic> json) {
    ThemeColor read(String key) {
      final color = ThemeColor.tryParse(_readString(json[key]));
      if (color == null) {
        throw FormatException('invalid color role "$key"');
      }
      return color;
    }

    return ColorRoles(
      primary: read('primary'),
      onPrimary: read('on_primary'),
      primaryContainer: read('primary_container'),
      onPrimaryContainer: read('on_primary_container'),
      secondary: read('secondary'),
      onSecondary: read('on_secondary'),
      secondaryContainer: read('secondary_container'),
      onSecondaryContainer: read('on_secondary_container'),
      tertiary: read('tertiary'),
      onTertiary: read('on_tertiary'),
      tertiaryContainer: read('tertiary_container'),
      onTertiaryContainer: read('on_tertiary_container'),
      error: read('error'),
      onError: read('on_error'),
      errorContainer: read('error_container'),
      onErrorContainer: read('on_error_container'),
      background: read('background'),
      onBackground: read('on_background'),
      surface: read('surface'),
      onSurface: read('on_surface'),
      surfaceVariant: read('surface_variant'),
      onSurfaceVariant: read('on_surface_variant'),
      surfaceContainerLowest: read('surface_container_lowest'),
      surfaceContainerLow: read('surface_container_low'),
      surfaceContainer: read('surface_container'),
      surfaceContainerHigh: read('surface_container_high'),
      surfaceContainerHighest: read('surface_container_highest'),
      outline: read('outline'),
      outlineVariant: read('outline_variant'),
      shadow: read('shadow'),
      scrim: read('scrim'),
      inverseSurface: read('inverse_surface'),
      inverseOnSurface: read('inverse_on_surface'),
      inversePrimary: read('inverse_primary'),
    );
  }

  /// Builds the roles from the ordered hex list of a D-Bus struct.
  ///
  /// The order is the declaration order of the service's `ColorRoles` struct.
  ///
  /// # Errors
  /// Throws a [FormatException] when [hexes] has the wrong length or a value
  /// is not a valid color.
  factory ColorRoles.fromHexList(List<String> hexes) {
    if (hexes.length != roleCount) {
      throw FormatException(
        'expected $roleCount color roles, received ${hexes.length}',
      );
    }

    ThemeColor at(int index) {
      final hex = hexes[index];
      final color = ThemeColor.tryParse(hex);
      if (color == null) {
        throw FormatException('invalid color role value "$hex"');
      }
      return color;
    }

    return ColorRoles(
      primary: at(0),
      onPrimary: at(1),
      primaryContainer: at(2),
      onPrimaryContainer: at(3),
      secondary: at(4),
      onSecondary: at(5),
      secondaryContainer: at(6),
      onSecondaryContainer: at(7),
      tertiary: at(8),
      onTertiary: at(9),
      tertiaryContainer: at(10),
      onTertiaryContainer: at(11),
      error: at(12),
      onError: at(13),
      errorContainer: at(14),
      onErrorContainer: at(15),
      background: at(16),
      onBackground: at(17),
      surface: at(18),
      onSurface: at(19),
      surfaceVariant: at(20),
      onSurfaceVariant: at(21),
      surfaceContainerLowest: at(22),
      surfaceContainerLow: at(23),
      surfaceContainer: at(24),
      surfaceContainerHigh: at(25),
      surfaceContainerHighest: at(26),
      outline: at(27),
      outlineVariant: at(28),
      shadow: at(29),
      scrim: at(30),
      inverseSurface: at(31),
      inverseOnSurface: at(32),
      inversePrimary: at(33),
    );
  }

  /// Roles keyed by the snake_case names the service uses.
  Map<String, ThemeColor> get asMap => {
    'primary': primary,
    'on_primary': onPrimary,
    'primary_container': primaryContainer,
    'on_primary_container': onPrimaryContainer,
    'secondary': secondary,
    'on_secondary': onSecondary,
    'secondary_container': secondaryContainer,
    'on_secondary_container': onSecondaryContainer,
    'tertiary': tertiary,
    'on_tertiary': onTertiary,
    'tertiary_container': tertiaryContainer,
    'on_tertiary_container': onTertiaryContainer,
    'error': error,
    'on_error': onError,
    'error_container': errorContainer,
    'on_error_container': onErrorContainer,
    'background': background,
    'on_background': onBackground,
    'surface': surface,
    'on_surface': onSurface,
    'surface_variant': surfaceVariant,
    'on_surface_variant': onSurfaceVariant,
    'surface_container_lowest': surfaceContainerLowest,
    'surface_container_low': surfaceContainerLow,
    'surface_container': surfaceContainer,
    'surface_container_high': surfaceContainerHigh,
    'surface_container_highest': surfaceContainerHighest,
    'outline': outline,
    'outline_variant': outlineVariant,
    'shadow': shadow,
    'scrim': scrim,
    'inverse_surface': inverseSurface,
    'inverse_on_surface': inverseOnSurface,
    'inverse_primary': inversePrimary,
  };

  /// Returns the normalized hex value of [role], or `null` when the service
  /// does not publish that role.
  String? hex(String role) => asMap[role]?.value;
}

/// Font families of the desktop theme.
class ThemeTypography {
  const ThemeTypography({required this.fontFamily, this.monoFamily});

  /// Font stack of the proportional UI font, as written by the theme author.
  final String fontFamily;

  /// Font family used for code, or `null` when the theme does not define one.
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
      monoFamily: _optional(value.children[1].asString()),
    );
  }

  /// Decodes the `typography` object of a JSON payload.
  factory ThemeTypography.fromJson(Map<String, dynamic> json) {
    return ThemeTypography(
      fontFamily: _readString(json['font_family']),
      monoFamily: _optional(json['mono_family']?.toString()),
    );
  }
}

/// Corner radius tokens of the desktop theme.
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
      radiusExtraSmall: _readDouble(json['radius_extra_small']),
      radiusSmall: _readDouble(json['radius_small']),
      radiusMedium: _readDouble(json['radius_medium']),
      radiusLarge: _readDouble(json['radius_large']),
      radiusExtraLarge: _readDouble(json['radius_extra_large']),
    );
  }
}

/// Animation durations and easing curves of the desktop theme.
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

  /// CSS cubic-bezier curve for standard transitions.
  final String curveStandard;

  /// CSS cubic-bezier curve for emphasized transitions.
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
      durationShortMs: _readInt(json['duration_short_ms']),
      durationMediumMs: _readInt(json['duration_medium_ms']),
      durationLongMs: _readInt(json['duration_long_ms']),
      curveStandard: _readString(json['curve_standard']),
      curveEmphasized: _readString(json['curve_emphasized']),
    );
  }
}

/// Maps an empty D-Bus string onto `null`.
String? _optional(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}

/// Reads a mandatory string out of a JSON object.
String _readString(Object? value) {
  if (value is String) {
    return value;
  }
  throw FormatException('expected a string, received ${value.runtimeType}');
}

/// Reads a mandatory integer out of a JSON object.
int _readInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('expected a number, received ${value.runtimeType}');
}

/// Reads a number that the service serializes as an `f32`.
double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('expected a number, received ${value.runtimeType}');
}

/// Reads a nested object out of a JSON payload.
Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('expected an object, received ${value.runtimeType}');
}
