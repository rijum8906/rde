import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Writes the global light/dark appearance of the desktop.
class SetModeUseCase {
  const SetModeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(AppearanceMode mode) =>
      _repository.setMode(mode);
}
