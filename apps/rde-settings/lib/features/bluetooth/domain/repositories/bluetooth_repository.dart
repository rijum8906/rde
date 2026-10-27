import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';

abstract interface class BluetoothRepository {
  /// Reads the adapter and every device BlueZ knows about.
  Future<Either<Failure, BluetoothSnapshot>> getSnapshot();

  /// Emits whenever BlueZ reports a change the page has to show.
  Stream<void> watchChanges();

  /// Turns the radio on or off.
  Future<Either<Failure, void>> setPowered(bool enabled);

  /// Makes the controller discoverable, or hides it again.
  Future<Either<Failure, void>> setDiscoverable(bool discoverable);

  /// Starts scanning for devices.
  Future<Either<Failure, void>> startDiscovery();

  /// Stops scanning for devices.
  Future<Either<Failure, void>> stopDiscovery();

  /// Pairs with [device].
  Future<Either<Failure, void>> pair(BluetoothDevice device);

  /// Connects to [device].
  Future<Either<Failure, void>> connect(BluetoothDevice device);

  /// Disconnects [device].
  Future<Either<Failure, void>> disconnect(BluetoothDevice device);

  /// Forgets [device] and its pairing.
  Future<Either<Failure, void>> forget(BluetoothDevice device);

  /// Marks [device] as trusted, or removes that trust.
  Future<Either<Failure, void>> setTrusted(
    BluetoothDevice device,
    bool trusted,
  );
}
