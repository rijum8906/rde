import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

/// Sets the charge end threshold, validating that the battery supports it and
/// that the value is in range.
class SetChargeEndThresholdUseCase {
  const SetChargeEndThresholdUseCase(this._repository);

  final BatteryHealthRepository _repository;

  Future<Either<Failure, void>> call({
    required BatterySnapshot current,
    required int percent,
  }) async {
    if (!current.chargeThresholdSupported) {
      return Left(Failure('This battery does not support charge thresholds.'));
    }
    if (percent < 60 || percent > 100) {
      return Left(
        Failure(
          'Charge end threshold must be between 60 and 100 (got $percent).',
        ),
      );
    }
    return _repository.setChargeEndThreshold(percent);
  }
}
