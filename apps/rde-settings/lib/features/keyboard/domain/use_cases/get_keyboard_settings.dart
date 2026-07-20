import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/keyboard/domain/entities/keyboard_settings.dart';
import 'package:rde_settings/features/keyboard/domain/repositories/keyboard_repository.dart';

class GetKeyboardSettingsUseCase {
  final KeyboardRepository _repository;

  const GetKeyboardSettingsUseCase(this._repository);

  Future<Either<Failure, KeyboardSettings>> call() async {
    return _repository.getSettings();
  }
}
