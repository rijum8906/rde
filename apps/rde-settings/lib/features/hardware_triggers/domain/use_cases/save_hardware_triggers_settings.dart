import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/hardware_triggers/domain/entities/hardware_triggers_settings.dart';
import 'package:rde_settings/features/hardware_triggers/domain/repositories/hardware_triggers_repository.dart';

class SaveHardwareTriggersSettingsUseCase {
  final HardwareTriggersRepository _repository;

  const SaveHardwareTriggersSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(HardwareTriggersSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
