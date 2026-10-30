import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

/// Emits one event per battery or power-profile change the page has to reload.
class WatchBatteryHealthUseCase {
  const WatchBatteryHealthUseCase(this._repository);

  final BatteryHealthRepository _repository;

  Stream<void> call() => _repository.watchChanges();
}
