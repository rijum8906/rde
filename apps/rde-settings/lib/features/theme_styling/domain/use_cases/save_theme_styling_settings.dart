import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_styling_settings.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_styling_repository.dart';

class SaveThemeStylingSettingsUseCase {
  final ThemeStylingRepository _repository;

  const SaveThemeStylingSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(ThemeStylingSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
