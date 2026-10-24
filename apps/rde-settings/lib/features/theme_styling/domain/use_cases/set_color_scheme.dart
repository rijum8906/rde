import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';

/// Writes the global light/dark preference of the desktop.
class SetColorSchemeUseCase {
  const SetColorSchemeUseCase(this._repository);

  final ThemeRepository _repository;

  Future<Either<Failure, void>> call(RdeColorScheme scheme) =>
      _repository.setColorScheme(scheme);
}
