import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';

/// Combines the individual `org.rde.Theme` calls into the UI-facing catalog.
///
/// The service exposes the registry, the author manifests, and the resolved
/// payload separately, so this datasource performs the fan-out: one property
/// read, one manifest read per installed theme, and one read of the payload the
/// desktop currently renders.
class DbusThemeDatasource {
  DbusThemeDatasource(this._proxy);

  final RdeThemeProxy _proxy;

  /// Loads the complete theme catalog from the service.
  ///
  /// # Returns
  /// A [ThemeCatalog] with the service state, every installed theme's manifest,
  /// and the resolved payload of the active theme.
  ///
  /// # Errors
  /// Returns an [RdeError] when any required service call fails.
  Future<Either<RdeError, ThemeCatalog>> loadCatalog() async {
    try {
      // Step 1: Read the service properties (active theme, appearance, list).
      final snapshot = _unwrap(await _proxy.fetchSnapshot());

      // Step 2: Resolve the author manifest of every installed theme.
      final manifests = <ThemeManifest>[];
      for (final id in snapshot.availableThemes) {
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

      // Step 4: Read the payload the desktop currently renders.
      final resolved = _unwrap(await _proxy.fetchResolvedTheme());

      return Right(
        ThemeCatalog(snapshot: snapshot, themes: manifests, resolved: resolved),
      );
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

  /// Emits whenever the service publishes a theme or changes the registry.
  ///
  /// Only the fact that something changed matters to the UI; the bloc reloads
  /// the catalog so every derived value stays consistent.
  Stream<void> watchThemeChanges() {
    final controller = StreamController<void>.broadcast();
    final subscriptions = <StreamSubscription<Object?>>[
      _proxy.watchThemeChanges().listen(
        (_) => controller.add(null),
        onError: (Object error) => controller.addError(error),
      ),
      _proxy.watchThemeListChanges().listen(
        (_) => controller.add(null),
        onError: (Object error) => controller.addError(error),
      ),
    ];

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  /// Unwraps a domain result, rethrowing the error for the local handler.
  ///
  /// The datasource performs several dependent calls; rethrowing keeps the
  /// happy path sequential and funnels every failure through one return point.
  T _unwrap<T>(Either<RdeError, T> result) {
    return result.fold((error) => throw error, (value) => value);
  }
}
