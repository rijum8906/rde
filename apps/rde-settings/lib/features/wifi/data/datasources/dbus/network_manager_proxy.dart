import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/data/datasource/network_manager/nm_device.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class NetworkManagerProxy {
  static const String serviceName = 'org.freedesktop.NetworkManager';
  static final DBusObjectPath nmObjectPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager',
  );
  static final nmDeviceObjectPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager/Devices',
  );

  final DBusClient client = RdeDbus.systemClient;

  NetworkManagerProxy();

  /// Get all network devices
  Future<Either<RdeError, List<String>>> devices() async {
    try {
      final response = await client.callMethod(
        destination: serviceName,
        path: nmObjectPath,
        interface: 'org.freedesktop.NetworkManager',
        name: 'GetDevices',
      );

      if (response.returnValues.isEmpty) {
        return const Right([]);
      }

      final array = response.returnValues.first as DBusArray;
      final devices = array.children
          .map((v) => (v as DBusObjectPath).value)
          .toList();
      return Right(devices);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Get the device type
  Future<Either<RdeError, int>> getDeviceType(String devicePath) async {
    try {
      // get the property name DeviceType
      final response = await client.callMethod(
        destination: 'org.freedesktop.NetworkManager', // Service name
        path: DBusObjectPath(devicePath), // Object path
        interface: 'org.freedesktop.DBus.Properties', // Interface
        name: 'Get', // Method name
        values: [
          DBusString('org.freedesktop.NetworkManager.Device'), // Interface name
          DBusString('DeviceType'), // Property name
        ],
      );

      return Right((response.values[0] as DBusInt16).value);
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }

  /// Get wifi network info
  Future<Either<RdeError, WifiNetwork>> getWifiNetork(String devicePath) async {
    try {
      // Mock/dummy network info for now to support UI state
      return Right(
        WifiNetwork(ssid: 'RDE-Net', security: 'WPA2/WPA3', strength: '95%'),
      );
    } catch (e) {
      return Left(RdeError(e.toString(), RdeErrorType.device));
    }
  }
}
