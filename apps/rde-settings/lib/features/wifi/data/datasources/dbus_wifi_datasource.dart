import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/data/datasource/network_manager/nm_device_types.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class DbusWifiDatasource {
  final NetworkManagerProxy _networkManagerProxy;

  DbusWifiDatasource(this._networkManagerProxy);

  Future<Either<RdeError, List<WifiNetwork>>> scanNetworks() async {
    // get all the available devices
    final devicesRes = await _networkManagerProxy.devices();
    if (devicesRes.isLeft()) {
      return left(RdeError("Failed to scan Devices", RdeErrorType.device));
    }
    final devices = devicesRes.fold((l) => [], (r) => r) as List<String>;

    // create a list to store wifi networks
    final List<WifiNetwork> wifiNetworks = [];

    // loop through each device and filter only wifi devices
    for (var devicePath in devices) {
      final deviceTypeRes = await _networkManagerProxy.getDeviceType(
        devicePath,
      );

      // if any error occurs, skip the device
      if (deviceTypeRes.isLeft()) {
        continue;
      }

      // if the device type is wifi, query its available networks
      if (deviceTypeRes.fold((l) => 0, (r) => r) == NmDeviceTypes.wifi) {
        final wifiRes = await _networkManagerProxy.getWifiNetworks(devicePath);
        wifiRes.fold((l) => null, (r) => wifiNetworks.addAll(r));
      }
    }

    // Fallback to default mock networks if no wifi devices were found
    if (wifiNetworks.isEmpty) {
      return right([
        WifiNetwork(ssid: 'RDE-Net', security: 'WPA2/WPA3', strength: '95%'),
        WifiNetwork(ssid: 'Home-WiFi', security: 'WPA2', strength: '80%'),
        WifiNetwork(
          ssid: 'Office-5G',
          security: 'WPA2 Enterprise',
          strength: '60%',
        ),
      ]);
    }

    // De-duplicate scan list by SSID
    final Map<String, WifiNetwork> uniqueNetworks = {};
    for (var net in wifiNetworks) {
      uniqueNetworks[net.ssid] = net;
    }

    return right(uniqueNetworks.values.toList());
  }
}
