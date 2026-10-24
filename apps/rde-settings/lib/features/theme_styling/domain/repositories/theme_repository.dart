import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Domain boundary for the `org.rde.Theme` service.
///
/// The UI never talks to D-Bus directly; every theme read or mutation goes
/// through this repository so presentation code stays testable.
abstract interface class ThemeRepository {
  /// Reads the current theme database state, installed themes, and the active
  /// theme's light/dark palettes.
  Future<Either<Failure, ThemeCatalog>> loadCatalog();

  /// Activates an installed theme.
  Future<Either<Failure, void>> setTheme(String theme);

  /// Creates a theme from a source color without activating it.
  Future<Either<Failure, void>> createTheme(String name, String sourceColor);

  /// Deletes an installed, non-active theme.
  Future<Either<Failure, void>> deleteTheme(String theme);

  /// Re-seeds the active theme with a new source color.
  Future<Either<Failure, void>> setSourceColor(String sourceColor);

  /// Writes the global light/dark preference.
  Future<Either<Failure, void>> setColorScheme(RdeColorScheme scheme);

  /// Re-reads the theme database on the service.
  Future<Either<Failure, void>> reload();

  /// Emits whenever the service reports a theme property change.
  Stream<void> watchThemeChanges();
}
