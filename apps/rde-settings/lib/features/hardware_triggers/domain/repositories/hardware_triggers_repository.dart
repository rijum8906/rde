import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/hardware_triggers/domain/entities/hardware_triggers_settings.dart';

abstract interface class HardwareTriggersRepository {
  Either<Failure, HardwareTriggersSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(HardwareTriggersSettings settings);
}
