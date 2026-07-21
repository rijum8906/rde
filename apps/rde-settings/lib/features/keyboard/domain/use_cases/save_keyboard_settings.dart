import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/keyboard/domain/entities/keyboard_settings.dart';
import 'package:rde_settings/features/keyboard/domain/repositories/keyboard_repository.dart';

class SaveKeyboardSettingsUseCase {
  final KeyboardRepository _repository;

  const SaveKeyboardSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(KeyboardSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
