import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_settings.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';

class GetBluetoothSettingsUseCase {
  final BluetoothRepository _repository;

  const GetBluetoothSettingsUseCase(this._repository);

  Future<Either<Failure, BluetoothSettings>> call() async {
    return _repository.getSettings();
  }
}
