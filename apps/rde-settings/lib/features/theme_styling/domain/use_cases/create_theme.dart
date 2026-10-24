import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Creates a theme from a source color.
class CreateThemeUseCase {
  const CreateThemeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(String name, String sourceColor) =>
      _repository.createTheme(name, sourceColor);
}
