import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_settings.dart';

abstract interface class BluetoothRepository {
  Either<Failure, BluetoothSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(BluetoothSettings settings);
}
