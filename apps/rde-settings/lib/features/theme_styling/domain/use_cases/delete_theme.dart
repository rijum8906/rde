import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Deletes an installed, non-active theme.
class DeleteThemeUseCase {
  const DeleteThemeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(String theme) =>
      _repository.deleteTheme(theme);
}
