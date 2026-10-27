import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

/// Toggles the charge threshold, validating that the battery supports it
/// before delegating to the repository.
class SetChargeThresholdUseCase {
  const SetChargeThresholdUseCase(this._repository);

  final BatteryHealthRepository _repository;

  Future<Either<Failure, void>> call({
    required BatterySnapshot current,
    required bool enabled,
  }) async {
    if (!current.chargeThresholdSupported) {
      return Left(Failure('This battery does not support charge thresholds.'));
    }
    return _repository.setChargeThresholdEnabled(enabled);
  }
}
