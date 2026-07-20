import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/user_profile/domain/entities/user_profile_settings.dart';

abstract interface class UserProfileRepository {
  Either<Failure, UserProfileSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(UserProfileSettings settings);
}
