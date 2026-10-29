import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/wallpaper/kde_wallpaper_seed_source.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/wallpaper_seed_source.dart';

/// Connects the theme datasource to the domain repository contract.
class ThemeRepositoryImpl implements ThemeRepository {
  /// Creates the repository.
  ///
  /// [wallpaper] resolves seeds from the desktop wallpaper; it defaults to the
  /// KDE implementation and is injectable for tests.
  ThemeRepositoryImpl(this._datasource, {WallpaperSeedSource? wallpaper})
    : _wallpaper = wallpaper ?? KdeWallpaperSeedSource();

  final DbusThemeDatasource _datasource;
  final WallpaperSeedSource _wallpaper;

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
    String primary = '',
    String secondary = '',
    String tertiary = '',
    String error = '',
  }) async {
    final result = await _datasource.updateDynamicTheme(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      error: error,
    );
    return result.mapLeft((failure) => Failure(failure.message));
  }

  @override
  Future<Either<Failure, DynamicSeeds>> seedsFromWallpaper() {
    return _wallpaper.seeds();
  }

  @override
  Future<Either<Failure, void>> reload() async {
    final result = await _datasource.reload();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Stream<void> watchThemeChanges() => _datasource.watchThemeChanges();
}
