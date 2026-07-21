import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_settings.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';

class SaveBluetoothSettingsUseCase {
  final BluetoothRepository _repository;

  const SaveBluetoothSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(BluetoothSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
