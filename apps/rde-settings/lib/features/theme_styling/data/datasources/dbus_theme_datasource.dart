import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus/rde_theme_proxy.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_theme_info.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Combines the individual `org.rde.Theme` calls into the UI-facing catalog.
///
/// The service exposes metadata and palettes through separate methods, so this
/// datasource performs the fan-out: one property read, one metadata read per
/// installed theme, and both palettes of the active theme.
class DbusThemeDatasource {
  DbusThemeDatasource(this._proxy);

  final RdeThemeProxy _proxy;

  /// Loads the complete theme catalog from the service.
  ///
  /// # Returns
  /// A [ThemeCatalog] with the service state, every installed theme's
  /// metadata, and the light/dark palettes of the active theme.
  ///
  /// # Errors
  /// Returns an [RdeError] when any required service call fails.
  Future<Either<RdeError, ThemeCatalog>> loadCatalog() async {
    try {
      // Step 1: Read the service properties (active theme, scheme, list).
      final snapshot = _unwrap(await _proxy.fetchSnapshot());

      // Step 2: Resolve manifest metadata for every installed theme. The list
      // is ordered by the service so the picker stays stable between reloads.
      final themes = <RdeThemeInfo>[];
      for (final name in snapshot.installedThemes) {
        themes.add(_unwrap(await _proxy.fetchThemeInfo(name)));
      }

      // Step 3: Generate both palettes of the active theme so the UI can
      // preview the inactive scheme without switching the desktop preference.
      final lightPalette = _unwrap(
        await _proxy.fetchPalette(snapshot.currentTheme, RdeColorScheme.light),
      );
      final darkPalette = _unwrap(
        await _proxy.fetchPalette(snapshot.currentTheme, RdeColorScheme.dark),
      );

      return Right(
        ThemeCatalog(
          snapshot: snapshot,
          themes: themes,
          lightPalette: lightPalette,
          darkPalette: darkPalette,
        ),
      );
    } on RdeError catch (error) {
      return Left(error);
    }
  }

  /// Activates an installed theme.
  Future<Either<RdeError, void>> setTheme(String theme) {
    return _proxy.setTheme(theme);
  }

  /// Creates a theme from a source color.
  Future<Either<RdeError, void>> createTheme(String name, String sourceColor) {
    return _proxy.createTheme(name, sourceColor);
  }

  /// Deletes an installed, non-active theme.
  Future<Either<RdeError, void>> deleteTheme(String theme) {
    return _proxy.deleteTheme(theme);
  }

  /// Re-seeds the active theme with a new source color.
  Future<Either<RdeError, void>> setSourceColor(String sourceColor) {
    return _proxy.setSourceColor(sourceColor);
  }

  /// Writes the global light/dark preference.
  Future<Either<RdeError, void>> setColorScheme(RdeColorScheme scheme) {
    return _proxy.setColorScheme(scheme);
  }

  /// Re-reads the theme database on the service.
  Future<Either<RdeError, void>> reload() {
    return _proxy.reload();
  }

  /// Emits whenever the service reports a theme property change.
  ///
  /// Only the fact that something changed matters to the UI; the bloc reloads
  /// the catalog so every derived value stays consistent.
  Stream<void> watchThemeChanges() {
    return _proxy.propertyChanges.map<void>((_) {});
  }

  /// Unwraps a domain result, rethrowing the error for the local handler.
  ///
  /// The datasource performs several dependent calls; rethrowing keeps the
  /// happy path sequential and funnels every failure through one return point.
  T _unwrap<T>(Either<RdeError, T> result) {
    return result.fold((error) => throw error, (value) => value);
  }
}
