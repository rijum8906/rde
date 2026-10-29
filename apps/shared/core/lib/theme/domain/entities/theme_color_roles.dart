import 'package:core/theme/domain/entities/theme_color.dart';
import 'package:core/utils/color_utils.dart';
import 'package:dbus/dbus.dart';

/// Complete set of Material 3 semantic color roles from the theme service.
class ThemeColorRoles {
  /// Creates the complete set of color roles.
  const ThemeColorRoles({
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

  /// Primary accent color.
  final ThemeColor primary;

  /// Content color displayed on the primary accent.
  final ThemeColor onPrimary;

  /// Primary tonal container color.
  final ThemeColor primaryContainer;

  /// Content color displayed on the primary container.
  final ThemeColor onPrimaryContainer;

  /// Secondary accent color.
  final ThemeColor secondary;

  /// Content color displayed on the secondary accent.
  final ThemeColor onSecondary;

  /// Secondary tonal container color.
  final ThemeColor secondaryContainer;

  /// Content color displayed on the secondary container.
  final ThemeColor onSecondaryContainer;

  /// Tertiary accent color.
  final ThemeColor tertiary;

  /// Content color displayed on the tertiary accent.
  final ThemeColor onTertiary;

  /// Tertiary tonal container color.
  final ThemeColor tertiaryContainer;

  /// Content color displayed on the tertiary container.
  final ThemeColor onTertiaryContainer;

  /// Error and destructive-action color.
  final ThemeColor error;

  /// Content color displayed on error surfaces.
  final ThemeColor onError;

  /// Error container color.
  final ThemeColor errorContainer;

  /// Content color displayed on error containers.
  final ThemeColor onErrorContainer;

  /// Legacy background role from the service contract.
  final ThemeColor background;

  /// Content color displayed on the legacy background role.
  final ThemeColor onBackground;

  /// Main application surface color.
  final ThemeColor surface;

  /// Content color displayed on surfaces.
  final ThemeColor onSurface;

  /// Legacy alternate surface role.
  final ThemeColor surfaceVariant;

  /// Content color displayed on alternate surfaces.
  final ThemeColor onSurfaceVariant;

  /// Lowest elevation surface container color.
  final ThemeColor surfaceContainerLowest;

  /// Low elevation surface container color.
  final ThemeColor surfaceContainerLow;

  /// Standard elevation surface container color.
  final ThemeColor surfaceContainer;

  /// High elevation surface container color.
  final ThemeColor surfaceContainerHigh;

  /// Highest elevation surface container color.
  final ThemeColor surfaceContainerHighest;

  /// Outline color for controls and boundaries.
  final ThemeColor outline;

  /// Subtle outline color for boundaries.
  final ThemeColor outlineVariant;

  /// Shadow color.
  final ThemeColor shadow;

  /// Scrim color used behind modal surfaces.
  final ThemeColor scrim;

  /// Inverse surface color.
  final ThemeColor inverseSurface;

  /// Content color displayed on inverse surfaces.
  final ThemeColor inverseOnSurface;

  /// Primary accent used on inverse surfaces.
  final ThemeColor inversePrimary;

  /// Number of roles published by the theme service.
  static const int roleCount = 34;

  /// Roles keyed by the snake_case names used by the service.
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

  /// Returns the normalized hex value for [role], or `null` if absent.
  String? hex(String role) => asMap[role]?.value;

  /// Decodes the color struct of a resolved theme payload.
  ///
  /// Throws [FormatException] if any role is missing or malformed.
  factory ThemeColorRoles.fromDbus(DBusValue value) {
    if (value is! DBusStruct || value.children.length != roleCount) {
      throw const FormatException('resolved colors must expose 34 roles');
    }
    return ThemeColorRoles.fromHexList(
      value.children.map((child) => child.asString()).toList(),
    );
  }

  /// Builds roles from the ordered hex values in a D-Bus struct.
  ///
  /// Throws [FormatException] if [hexes] has the wrong length or contains an
  /// invalid color.
  factory ThemeColorRoles.fromHexList(List<String> hexes) {
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

    return ThemeColorRoles(
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

  /// Decodes the `colors` object of a resolved-theme JSON payload.
  ///
  /// Throws [FormatException] if a role is missing or malformed.
  factory ThemeColorRoles.fromJson(Map<String, dynamic> json) {
    ThemeColor read(String key) {
      final color = ThemeColor.tryParse(readString(json[key]));
      if (color == null) {
        throw FormatException('invalid color role "$key"');
      }
      return color;
    }

    return ThemeColorRoles(
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
}

/// Short alias for [ThemeColorRoles].
typedef ColorRoles = ThemeColorRoles;
