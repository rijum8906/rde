import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus_battery_health_datasource.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';

/// UPower-backed implementation of [BatteryHealthRepository].
///
/// The repository is the boundary between the UI vocabulary ([Failure]) and the
/// data vocabulary ([RdeError]): every result is mapped here, so the use cases
/// and the bloc never see a D-Bus error type.
class BatteryHealthRepositoryImpl implements BatteryHealthRepository {
  BatteryHealthRepositoryImpl(this._datasource);

  final DbusBatteryHealthDatasource _datasource;

  @override
  Stream<void> watchChanges() => _datasource.watchChanges();

  @override
  Future<Either<Failure, BatterySnapshot>> getSnapshot() async {
    final result = await _datasource.getSnapshot();
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setChargeThresholdEnabled(bool enabled) async {
    final result = await _datasource.setChargeThresholdEnabled(enabled);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setChargeEndThreshold(int percent) async {
    final result = await _datasource.setChargeEndThreshold(percent);
    return result.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setPowerProfile(String profile) async {
    final result = await _datasource.setPowerProfile(profile);
    return result.mapLeft((error) => Failure(error.message));
  }
}
