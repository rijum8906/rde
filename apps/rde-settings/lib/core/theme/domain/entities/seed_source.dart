/// Input the built-in dynamic theme derives its seed color from.
enum SeedSource {
  /// Derive the seed color from the desktop wallpaper.
  wallpaper('wallpaper'),

  /// Use the explicit seed color stored in the settings file.
  fixed('fixed');

  const SeedSource(this.dbusValue);

  /// Value used on the wire for the `DynamicSeedSource` property.
  final String dbusValue;

  /// Maps a value received over D-Bus onto the enum.
  ///
  /// The service only publishes `wallpaper` or `fixed`, so an unknown value
  /// falls back to [SeedSource.wallpaper] to keep the UI usable.
  static SeedSource fromDbus(String value) {
    final normalized = value.trim().toLowerCase();
    for (final source in SeedSource.values) {
      if (source.dbusValue == normalized) {
        return source;
      }
    }
    return SeedSource.wallpaper;
  }
}
