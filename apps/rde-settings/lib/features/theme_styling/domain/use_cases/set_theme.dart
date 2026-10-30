import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Activates an installed theme on the desktop.
class SetThemeUseCase {
  const SetThemeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(String theme) =>
      _repository.setTheme(theme);
}
