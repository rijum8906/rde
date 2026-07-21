import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_styling_settings.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_styling_repository.dart';

class GetThemeStylingSettingsUseCase {
  final ThemeStylingRepository _repository;

  const GetThemeStylingSettingsUseCase(this._repository);

  Future<Either<Failure, ThemeStylingSettings>> call() async {
    return _repository.getSettings();
  }
}
