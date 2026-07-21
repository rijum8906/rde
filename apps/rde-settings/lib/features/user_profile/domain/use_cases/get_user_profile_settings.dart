import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/user_profile/domain/entities/user_profile_settings.dart';
import 'package:rde_settings/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetUserProfileSettingsUseCase {
  final UserProfileRepository _repository;

  const GetUserProfileSettingsUseCase(this._repository);

  Future<Either<Failure, UserProfileSettings>> call() async {
    return _repository.getSettings();
  }
}
