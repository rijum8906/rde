import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';

/// Domain boundary for the `org.rde.Theme` service.
///
/// The UI never talks to D-Bus directly; every theme read or mutation goes
/// through this repository so presentation code stays testable. Reads are split
/// per resource — payload, manifests, properties — so a change to one never
/// costs a read of the others.
abstract interface class ThemeRepository {
  /// Reads the service properties: active theme, appearance, registry, version.
  Future<Either<Failure, ThemeSnapshot>> loadSnapshot();

  /// Reads the payload the desktop currently renders.
  Future<Either<Failure, ResolvedTheme>> getResolvedTheme();

  /// Reads the manifests of every theme the picker offers.
  Future<Either<Failure, List<ThemeManifest>>> loadThemes();

  /// Resolves [theme] for [mode] without committing it.
  Future<Either<Failure, ResolvedTheme>> preview(
    String theme,
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]);

  /// Activates an installed theme.
  Future<Either<Failure, void>> setTheme(String theme);

  /// Switches the desktop light/dark appearance.
  Future<Either<Failure, void>> setMode(AppearanceMode mode);

  /// Updates the seed colors of the built-in dynamic theme.
  ///
  /// Every argument defaults to an empty string, which keeps that role's stored
  /// seed, so callers can re-seed a single family.
  Future<Either<Failure, void>> updateDynamicTheme({
    String primary,
    String secondary,
    String tertiary,
    String error,
  });

  /// Extracts the four seeds from the wallpaper the desktop currently shows.
  Future<Either<Failure, DynamicSeeds>> seedsFromWallpaper();

  /// Re-reads manifests, variant files, and settings on the service.
  Future<Either<Failure, void>> reload();

  /// Emits the payload the service publishes, once per change.
  Stream<ResolvedTheme> watchResolvedTheme();

  /// Emits the registry identifiers, once per change.
  Stream<List<String>> watchThemeList();
}
