import 'package:core/theme/domain/entities/theme_color.dart';

/// Light or dark appearance managed globally by the `org.rde.Theme` service.
///
/// The service accepts only the lowercase strings `light` and `dark`; the enum
/// keeps the wire representation next to the Dart values so neither the data
/// layer nor the UI has to hard-code magic strings.
enum AppearanceMode {
  light('light'),
  dark('dark');

  const AppearanceMode(this.dbusValue);

  /// Value used on the wire for the `Mode` property and `SetMode` argument.
  final String dbusValue;

  /// Whether this appearance is the dark variant.
  bool get isDark => this == AppearanceMode.dark;

  /// Maps a value received over D-Bus onto the enum.
  ///
  /// The service only publishes `light` or `dark`, so an unknown value falls
  /// back to [AppearanceMode.dark] to keep the UI usable if a future service
  /// version adds a variant this client does not know yet.
  static AppearanceMode fromDbus(String value) {
    final normalized = value.trim().toLowerCase();
    for (final mode in AppearanceMode.values) {
      if (mode.dbusValue == normalized) {
        return mode;
      }
    }
    return AppearanceMode.dark;
  }

  /// Maps the numeric enum index the service uses in manifest descriptors.
  ///
  /// Descriptors encode `Light` as `0` and `Dark` as `1`.
  static AppearanceMode fromIndex(int index) {
    if (index < 0 || index >= AppearanceMode.values.length) {
      return AppearanceMode.light;
    }
    return AppearanceMode.values[index];
  }

  /// Infers the appearance from a surface color.
  ///
  /// Used only as a fallback when the authoritative `Mode` property cannot be
  /// read, so a transient bus error does not leave the app on the wrong
  /// brightness.
  static AppearanceMode fromSurface(ThemeColor surface) {
    return surface.toColor().computeLuminance() < 0.5
        ? AppearanceMode.dark
        : AppearanceMode.light;
  }
}

/// Contrast axis of a theme variant.
///
/// The service publishes one variant per `(mode, contrast)` combination and
/// resolves the one matching the persisted accessibility preference.
enum ContrastLevel {
  normal('normal'),
  medium('medium'),
  high('high');

  const ContrastLevel(this.dbusValue);

  /// Value used on the wire for `Preview` arguments and manifest descriptors.
  final String dbusValue;

  /// Maps a wire value onto the enum, defaulting to [ContrastLevel.normal].
  static ContrastLevel fromDbus(String value) {
    final normalized = value.trim().toLowerCase();
    for (final level in ContrastLevel.values) {
      if (level.dbusValue == normalized) {
        return level;
      }
    }
    return ContrastLevel.normal;
  }

  /// Maps the numeric enum index the service uses in manifest descriptors.
  static ContrastLevel fromIndex(int index) {
    if (index < 0 || index >= ContrastLevel.values.length) {
      return ContrastLevel.normal;
    }
    return ContrastLevel.values[index];
  }
}
