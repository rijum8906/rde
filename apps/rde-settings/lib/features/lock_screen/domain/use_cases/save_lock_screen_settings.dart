import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/lock_screen/domain/entities/lock_screen_settings.dart';
import 'package:rde_settings/features/lock_screen/domain/repositories/lock_screen_repository.dart';

class SaveLockScreenSettingsUseCase {
  final LockScreenRepository _repository;

  const SaveLockScreenSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(LockScreenSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
