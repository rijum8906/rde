import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/lock_screen/domain/entities/lock_screen_settings.dart';
import 'package:rde_settings/features/lock_screen/domain/repositories/lock_screen_repository.dart';

class GetLockScreenSettingsUseCase {
  final LockScreenRepository _repository;

  const GetLockScreenSettingsUseCase(this._repository);

  Future<Either<Failure, LockScreenSettings>> call() async {
    return _repository.getSettings();
  }
}
