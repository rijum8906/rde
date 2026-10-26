import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/domain/entities/seed_source.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Domain boundary for the `org.rde.Theme` service.
///
/// The UI never talks to D-Bus directly; every theme read or mutation goes
/// through this repository so presentation code stays testable.
abstract interface class ThemeRepository {
  /// Reads the service state, the installed themes' manifests, and the payload
  /// the desktop currently renders.
  Future<Either<Failure, ThemeCatalog>> loadCatalog();

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

  /// Updates the inputs of the built-in dynamic theme.
  Future<Either<Failure, void>> updateDynamicTheme({
    required SeedSource seedSource,
    String seed,
    String wallpaper,
  });

  /// Re-reads manifests, variant files, and settings on the service.
  Future<Either<Failure, void>> reload();

  /// Emits whenever the service publishes a theme or changes the registry.
  Stream<void> watchThemeChanges();
}
