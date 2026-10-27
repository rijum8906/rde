import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus_bluetooth_datasource.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final DbusBluetoothDatasource _datasource;

  BluetoothRepositoryImpl(this._datasource);

  @override
  Stream<void> watchChanges() {
    return _datasource.watchChanges();
  }

  @override
  Future<Either<Failure, BluetoothSnapshot>> getSnapshot() async {
    final res = await _datasource.getSnapshot();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setPowered(bool enabled) async {
    final res = await _datasource.setPowered(enabled);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setDiscoverable(bool discoverable) async {
    final res = await _datasource.setDiscoverable(discoverable);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> startDiscovery() async {
    final res = await _datasource.startDiscovery();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> stopDiscovery() async {
    final res = await _datasource.stopDiscovery();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> pair(BluetoothDevice device) async {
    final res = await _datasource.pair(device.address);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> connect(BluetoothDevice device) async {
    final res = await _datasource.connect(device.address);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> disconnect(BluetoothDevice device) async {
    final res = await _datasource.disconnect(device.address);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> forget(BluetoothDevice device) async {
    final res = await _datasource.forget(device.address);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setTrusted(
    BluetoothDevice device,
    bool trusted,
  ) async {
    final res = await _datasource.setTrusted(device.address, trusted);
    return res.mapLeft((error) => Failure(error.message));
  }
}
