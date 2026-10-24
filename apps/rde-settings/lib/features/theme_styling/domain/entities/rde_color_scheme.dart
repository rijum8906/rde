/// Light or dark appearance managed globally by the `org.rde.Theme` service.
///
/// The D-Bus API only accepts the lowercase strings `light` and `dark`; the
/// enum keeps the wire representation next to the Dart values so neither the
/// data layer nor the UI has to hard-code magic strings.
enum RdeColorScheme {
  light('light'),
  dark('dark');

  const RdeColorScheme(this.dbusValue);

  /// Value used on the wire for the `ColorScheme` property and method
  /// arguments.
  final String dbusValue;

  /// Whether this scheme is the dark variant.
  bool get isDark => this == RdeColorScheme.dark;

  /// Maps a value received over D-Bus onto the enum.
  ///
  /// The theme service only emits `light` or `dark`, so an unknown value falls
  /// back to [RdeColorScheme.dark] to keep the UI usable if a future service
  /// version adds a variant this client does not know yet.
  static RdeColorScheme fromDbus(String value) {
    final normalized = value.trim().toLowerCase();
    for (final scheme in RdeColorScheme.values) {
      if (scheme.dbusValue == normalized) {
        return scheme;
      }
    }
    return RdeColorScheme.dark;
  }
}
