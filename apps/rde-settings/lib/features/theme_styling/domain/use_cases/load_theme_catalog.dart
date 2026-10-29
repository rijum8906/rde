import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Loads the theme database, installed themes, and active palettes.
class LoadThemeCatalogUseCase {
  const LoadThemeCatalogUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, ThemeCatalog>> call() => _repository.loadCatalog();
}
