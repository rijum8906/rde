import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_health_settings.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

class GetBatteryHealthSettingsUseCase {
  final BatteryHealthRepository _repository;

  const GetBatteryHealthSettingsUseCase(this._repository);

  Future<Either<Failure, BatteryHealthSettings>> call() async {
    return _repository.getSettings();
  }
}
