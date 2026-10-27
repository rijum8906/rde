import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

class ReadBatteryHealthUseCase {
  const ReadBatteryHealthUseCase(this._repository);

  final BatteryHealthRepository _repository;

  Future<Either<Failure, BatterySnapshot>> call() => _repository.getSnapshot();
}
