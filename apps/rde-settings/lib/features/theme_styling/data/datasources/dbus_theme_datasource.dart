import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';

/// Exposes the individual `org.rde.Theme` reads the page needs.
///
/// The service keeps the registry, the author manifests, and the resolved
/// payload apart, and so does this datasource. Nothing here fans out into a
/// combined read: the caller asks for the one thing it needs, which keeps a
/// color update from re-reading every installed theme's manifest.
class DbusThemeDatasource {
  DbusThemeDatasource(this._proxy);

  final RdeThemeProxy _proxy;

  /// Reads the service properties: active theme, appearance, registry, version.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is unreachable or a property cannot
  /// be read.
  Future<Either<RdeError, ThemeSnapshot>> loadSnapshot() {
    return _proxy.fetchSnapshot();
  }

  /// Reads the payload the desktop currently renders.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is unreachable or the reply is
  /// malformed.
  Future<Either<RdeError, ResolvedTheme>> getResolvedTheme() {
    return _proxy.fetchResolvedTheme();
  }

  /// Reads the author manifest of every installed theme.
  ///
  /// The built-in dynamic theme is not part of the machine-owned registry, so
  /// it is appended explicitly to keep it pickable.
  ///
  /// # Returns
  /// The manifests in registry order, with the built-in theme first.
  ///
  /// # Errors
  /// Returns an [RdeError] when the registry or any manifest cannot be read.
  Future<Either<RdeError, List<ThemeManifest>>> loadThemes() async {
    try {
      // Step 1: Read the registry identifiers.
      final ids = _unwrap(await _proxy.listThemes());

      // Step 2: Resolve the manifest of every installed theme.
      final manifests = <ThemeManifest>[];
      for (final id in ids) {
        manifests.add(_unwrap(await _proxy.fetchThemeManifest(id)));
      }

      // Step 3: Keep the built-in dynamic theme pickable even though it is not
      // part of the machine-owned registry.
      if (!manifests.any((theme) => theme.name == ThemeManifest.dynamicId)) {
        manifests.insert(
          0,
          _unwrap(await _proxy.fetchThemeManifest(ThemeManifest.dynamicId)),
        );
      }

      return Right(manifests);
    } on RdeError catch (error) {
      return Left(error);
    }
  }

  /// Resolves a theme for one appearance without committing it.
  Future<Either<RdeError, ResolvedTheme>> preview(
    String theme,
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]) {
    return _proxy.preview(themeId: theme, mode: mode, contrast: contrast);
  }

  /// Activates an installed theme.
  Future<Either<RdeError, void>> setTheme(String theme) {
    return _proxy.setActiveTheme(theme);
  }

  /// Switches the desktop light/dark appearance.
  Future<Either<RdeError, void>> setMode(AppearanceMode mode) {
    return _proxy.setMode(mode);
  }

  /// Updates the seed colors of the built-in dynamic theme.
  Future<Either<RdeError, void>> updateDynamicTheme({
    String primary = '',
    String secondary = '',
    String tertiary = '',
    String error = '',
  }) {
    return _proxy.updateDynamicTheme(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
    );
  }

  /// Re-reads the theme database on the service.
  Future<Either<RdeError, void>> reload() {
    return _proxy.reload();
  }

  /// Emits the payload the service published, once per change.
  Stream<ResolvedTheme> watchResolvedTheme() => _proxy.watchResolvedTheme();

  /// Emits the registry identifiers, once per change.
  ///
  /// Only the identifiers are shipped: the manifests are re-read by
  /// [loadThemes] when the list actually differs from what the page shows.
  Stream<List<String>> watchThemeList() => _proxy.watchThemeList();

  /// Unwraps a domain result, rethrowing the error for the local handler.
  ///
  /// The registry fan-out performs several dependent calls; rethrowing keeps the
  /// happy path sequential and funnels every failure through one return point.
  T _unwrap<T>(Either<RdeError, T> result) {
    return result.fold((error) => throw error, (value) => value);
  }
}
