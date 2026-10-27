import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

/// Maps the page's Wi-Fi operations onto the NetworkManager proxy.
class DbusWifiDatasource {
  DbusWifiDatasource(this._networkManager);

  final NetworkManagerProxy _networkManager;

  /// Requests a scan and returns the visible networks.
  Future<Either<RdeError, List<WifiNetwork>>> scanNetworks() {
    return _networkManager.scanNetworks();
  }

  /// Connects to [ssid], adding a profile when [password] is present.
  Future<Either<RdeError, void>> connectToNetwork(
    String ssid,
    String? password,
  ) {
    return _networkManager.connect(ssid, password: password);
  }

  /// Disconnects the active Wi-Fi connection.
  Future<Either<RdeError, void>> disconnect() {
    return _networkManager.disconnect();
  }

  /// Deletes the saved profile for [ssid].
  Future<Either<RdeError, void>> forgetNetwork(String ssid) {
    return _networkManager.forget(ssid);
  }

  /// Returns the saved Wi-Fi profiles as page entities.
  Future<Either<RdeError, List<WifiNetwork>>> getSavedNetworks() async {
    final result = await _networkManager.savedSsids();
    return result.map(
      (ssids) => ssids
          .map(
            (ssid) =>
                WifiNetwork(ssid: ssid, security: 'Saved', strength: '0%'),
          )
          .toList(),
    );
  }

  /// Returns the currently associated network, or `null` when disconnected.
  Future<Either<RdeError, WifiNetwork?>> getCurrentNetwork() {
    return _networkManager.currentNetwork();
  }

  /// Returns the autoconnect priority of [ssid]'s saved profile.
  Future<Either<RdeError, int>> getNetworkPriority(String ssid) {
    return _networkManager.priority(ssid);
  }

  /// Updates the autoconnect priority of [ssid]'s saved profile.
  Future<Either<RdeError, void>> setNetworkPriority(String ssid, int priority) {
    return _networkManager.setPriority(ssid, priority);
  }

  /// Reads the Wi-Fi radio state.
  Future<Either<RdeError, bool>> getEnabled() {
    return _networkManager.wirelessEnabled();
  }

  /// Turns the Wi-Fi radio on or off.
  Future<Either<RdeError, void>> setEnabled(bool value) {
    return _networkManager.setWirelessEnabled(value);
  }
}
