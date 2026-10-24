import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
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
  Future<Either<Failure, void>> setTheme(String theme) async {
    final result = await _datasource.setTheme(theme);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> createTheme(
    String name,
    String sourceColor,
  ) async {
    final result = await _datasource.createTheme(name, sourceColor);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> deleteTheme(String theme) async {
    final result = await _datasource.deleteTheme(theme);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setSourceColor(String sourceColor) async {
    final result = await _datasource.setSourceColor(sourceColor);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setColorScheme(RdeColorScheme scheme) async {
    final result = await _datasource.setColorScheme(scheme);
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
