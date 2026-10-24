import 'rde_color_scheme.dart';

/// Material 3 palette of one theme for one color scheme.
///
/// The `org.rde.Theme` service returns the palette as a map from canonical
/// snake_case role name (`primary_container`, `on_surface`, …) to `#RRGGBB`,
/// so the UI can render every role without knowing the service's struct
/// layout.
class RdePalette {
  const RdePalette({
    required this.theme,
    required this.scheme,
    required this.roles,
  });

  /// Identifier of the theme the palette was generated from.
  final String theme;

  /// Scheme the palette belongs to.
  final RdeColorScheme scheme;

  /// Color roles keyed by their snake_case name, values in `#RRGGBB`.
  final Map<String, String> roles;

  /// Returns the hex value of [role], or `null` when the service did not send
  /// that role.
  String? hex(String role) => roles[role];

  /// Returns the packed ARGB value of [role], or `null` when the role is
  /// missing or not a valid hex color.
  int? argb(String role) {
    final value = roles[role];
    if (value == null) {
      return null;
    }
    return parseHexColor(value);
  }

  /// Parses a `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB` color into packed ARGB.
  ///
  /// # Parameters
  /// - [value]: hexadecimal color string
  ///
  /// # Returns
  /// The opaque ARGB value, or `null` when the string is not a valid color.
  static int? parseHexColor(String value) {
    // Step 1: Normalize the input by dropping an optional leading hash.
    var hex = value.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    // Step 2: Expand the three-digit shorthand into six digits.
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }

    // Step 3: Only six-digit colors are accepted; anything else is invalid.
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
}
