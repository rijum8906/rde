import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_health_settings.dart';

abstract interface class BatteryHealthRepository {
  Either<Failure, BatteryHealthSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(BatteryHealthSettings settings);
}
