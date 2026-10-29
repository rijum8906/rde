/// Role family one dynamic seed drives.
enum DynamicSeedRole {
  /// Accent family, and the neutral surfaces derived from it.
  primary('Primary'),

  /// Supporting accent family.
  secondary('Secondary'),

  /// Contrasting accent family.
  tertiary('Tertiary'),

  /// Error and destructive-action family.
  error('Error');

  const DynamicSeedRole(this.label);

  /// Human-readable name shown next to the seed's color.
  final String label;
}

/// The four seed colors the built-in `rde-dynamic` palette is generated from.
///
/// The service renders one tonal palette per seed, so changing a single role
/// only repaints that family. The seeds are plain `#RRGGBB` strings because
/// that is what `org.rde.Theme` stores and publishes.
class DynamicSeeds {
  const DynamicSeeds({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.error,
  });

  /// Primary seed, which also drives the neutral surfaces.
  final String primary;

  /// Secondary seed.
  final String secondary;

  /// Tertiary seed.
  final String tertiary;

  /// Error seed.
  final String error;

  /// Seeds the service ships with until the desktop extracts or the user picks colors.
  static const DynamicSeeds fallback = DynamicSeeds(
    primary: '#4285F4',
    secondary: '#4285F4',
    tertiary: '#4285F4',
    error: '#BA1A1A',
  );

  /// Returns the seed that drives [role].
  String seedFor(DynamicSeedRole role) {
    switch (role) {
      case DynamicSeedRole.primary:
        return primary;
      case DynamicSeedRole.secondary:
        return secondary;
      case DynamicSeedRole.tertiary:
        return tertiary;
      case DynamicSeedRole.error:
        return error;
    }
  }

  /// Returns a copy with [role] replaced by [seed].
  DynamicSeeds withSeed(DynamicSeedRole role, String seed) {
    return DynamicSeeds(
      primary: role == DynamicSeedRole.primary ? seed : primary,
      secondary: role == DynamicSeedRole.secondary ? seed : secondary,
      tertiary: role == DynamicSeedRole.tertiary ? seed : tertiary,
      error: role == DynamicSeedRole.error ? seed : error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicSeeds &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          secondary == other.secondary &&
          tertiary == other.tertiary &&
          error == other.error;

  @override
  int get hashCode =>
      primary.hashCode ^
      secondary.hashCode ^
      tertiary.hashCode ^
      error.hashCode;
}
