import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/domain/entities/seed_source.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Connects the theme datasource to the domain repository contract.
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._datasource);

  final DbusThemeDatasource _datasource;

  @override
  Future<Either<Failure, ThemeCatalog>> loadCatalog() async {
    final result = await _datasource.loadCatalog();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, ResolvedTheme>> preview(
    String theme,
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]) async {
    final result = await _datasource.preview(theme, mode, contrast);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setTheme(String theme) async {
    final result = await _datasource.setTheme(theme);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setMode(AppearanceMode mode) async {
    final result = await _datasource.setMode(mode);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> updateDynamicTheme({
    required SeedSource seedSource,
    String seed = '',
    String wallpaper = '',
  }) async {
    final result = await _datasource.updateDynamicTheme(
      seedSource: seedSource,
      seed: seed,
      wallpaper: wallpaper,
    );
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> reload() async {
    final result = await _datasource.reload();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Stream<void> watchThemeChanges() => _datasource.watchThemeChanges();
}
