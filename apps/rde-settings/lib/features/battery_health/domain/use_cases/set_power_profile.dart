import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

/// Sets the system power profile. Valid profiles are `performance`,
/// `balanced`, and `power-saver`.
class SetPowerProfileUseCase {
  const SetPowerProfileUseCase(this._repository);

  final BatteryHealthRepository _repository;

  static const validProfiles = {'performance', 'balanced', 'power-saver'};

  Future<Either<Failure, void>> call(String profile) async {
    if (!validProfiles.contains(profile)) {
      return Left(Failure('Unknown power profile: $profile'));
    }
    return _repository.setPowerProfile(profile);
  }
}
