import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/user_profile/domain/entities/user_profile_settings.dart';
import 'package:rde_settings/features/user_profile/domain/repositories/user_profile_repository.dart';

class SaveUserProfileSettingsUseCase {
  final UserProfileRepository _repository;

  const SaveUserProfileSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(UserProfileSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
