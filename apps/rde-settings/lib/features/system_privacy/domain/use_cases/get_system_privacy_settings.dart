import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/system_privacy/domain/entities/system_privacy_settings.dart';
import 'package:rde_settings/features/system_privacy/domain/repositories/system_privacy_repository.dart';

class GetSystemPrivacySettingsUseCase {
  final SystemPrivacyRepository _repository;

  const GetSystemPrivacySettingsUseCase(this._repository);

  Future<Either<Failure, SystemPrivacySettings>> call() async {
    return _repository.getSettings();
  }
}
