import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus/bluez_proxy.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';

/// Maps the page's Bluetooth operations onto the BlueZ proxy.
class DbusBluetoothDatasource {
  DbusBluetoothDatasource(this._bluez);

  final BluezProxy _bluez;

  /// Watches BlueZ for events that change what the page shows.
  Stream<void> watchChanges() {
    return _bluez.watchChanges();
  }

  /// Reads the adapter and every device the daemon knows.
  Future<Either<RdeError, BluetoothSnapshot>> getSnapshot() {
    return _bluez.snapshot();
  }

  /// Turns the radio on or off.
  Future<Either<RdeError, void>> setPowered(bool enabled) {
    return _bluez.setPowered(enabled);
  }

  /// Makes the controller discoverable, or hides it again.
  Future<Either<RdeError, void>> setDiscoverable(bool discoverable) {
    return _bluez.setDiscoverable(discoverable);
  }

  /// Starts scanning for devices.
  Future<Either<RdeError, void>> startDiscovery() {
    return _bluez.startDiscovery();
  }

  /// Stops scanning for devices.
  Future<Either<RdeError, void>> stopDiscovery() {
    return _bluez.stopDiscovery();
  }

  /// Pairs with [address].
  Future<Either<RdeError, void>> pair(String address) {
    return _bluez.pair(address);
  }

  /// Connects to [address].
  Future<Either<RdeError, void>> connect(String address) {
    return _bluez.connect(address);
  }

  /// Disconnects [address].
  Future<Either<RdeError, void>> disconnect(String address) {
    return _bluez.disconnect(address);
  }

  /// Forgets [address] and its pairing.
  Future<Either<RdeError, void>> forget(String address) {
    return _bluez.forget(address);
  }

  /// Marks [address] as trusted, or removes that trust.
  Future<Either<RdeError, void>> setTrusted(String address, bool trusted) {
    return _bluez.setTrusted(address, trusted);
  }
}
