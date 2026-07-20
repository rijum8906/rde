import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/system_privacy/domain/entities/system_privacy_settings.dart';
import 'package:rde_settings/features/system_privacy/domain/repositories/system_privacy_repository.dart';

class SaveSystemPrivacySettingsUseCase {
  final SystemPrivacyRepository _repository;

  const SaveSystemPrivacySettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(SystemPrivacySettings settings) async {
    return _repository.saveSettings(settings);
  }
}
