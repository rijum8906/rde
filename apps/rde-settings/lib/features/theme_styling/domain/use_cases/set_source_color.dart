import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Re-seeds the active theme and regenerates its Material 3 palette.
class SetSourceColorUseCase {
  const SetSourceColorUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(String sourceColor) =>
      _repository.setSourceColor(sourceColor);
}
