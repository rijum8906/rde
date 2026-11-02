/// Brightness as the `org.rde.Brightness` service reports it.
///
/// The service owns the backlight, so this is a snapshot: every field is read
/// back from the daemon after a change instead of being derived here.
class BrightnessLevel {
  const BrightnessLevel({
    required this.percent,
    required this.raw,
    required this.max,
    required this.version,
  });

  /// Current brightness percentage (0-100).
  final int percent;

  /// Current raw value on the target display's scale.
  final int raw;

  /// Maximum raw value on the target display's scale.
  final int max;

  /// Version of the brightness service that answered.
  final String version;

  /// Whether the target display exposes a usable raw scale.
  bool get hasRange => max > 0;

  /// Returns a copy with the given fields replaced.
  BrightnessLevel copyWith({
    int? percent,
    int? raw,
    int? max,
    String? version,
  }) {
    return BrightnessLevel(
      percent: percent ?? this.percent,
      raw: raw ?? this.raw,
      max: max ?? this.max,
      version: version ?? this.version,
    );
  }
}
