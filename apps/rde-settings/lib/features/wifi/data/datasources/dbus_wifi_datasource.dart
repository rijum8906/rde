import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/data/datasource/network_manager/nm_device_types.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class DbusWifiDatasource {
  final NetworkManagerProxy _networkManagerProxy;

  Future<Either<RdeError, List<WifiNetwork>>> scanNetworks() async {
    // get all the available devices
    final devicesRes = await _networkManagerProxy.devices();
    if (devicesRes.isLeft()) {
      return left(RdeError("Failed to scan Devices", RdeErrorType.device));
    }
    final devices = devicesRes.fold((l) => [], (r) => r) as List<String>;

    // create a list to store wifi devices
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

      // if the device type is wifi, add it to the list
      if (deviceTypeRes.fold((l) => 0, (r) => r) == NmDeviceTypes.wifi) {
        final wifiRes = await _networkManagerProxy.getWifiNetork(devicePath);
        wifiRes.fold((l) => null, (r) => wifiNetworks.add(r));
      }
    }

    return right(wifiNetworks);
  }
}
