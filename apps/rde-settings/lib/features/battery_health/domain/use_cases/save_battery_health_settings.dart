import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_health_settings.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

class SaveBatteryHealthSettingsUseCase {
  final BatteryHealthRepository _repository;

  const SaveBatteryHealthSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(BatteryHealthSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
