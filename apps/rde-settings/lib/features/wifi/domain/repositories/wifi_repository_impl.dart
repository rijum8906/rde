import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class WifiRepositoryImpl implements WifiRepository {
  final DbusWifiDatasource _wifiDatasource;

  WifiRepositoryImpl(this._wifiDatasource);

  @override
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks() async {
    final res = await _wifiDatasource.scanNetworks();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  }) async {
    final res = await _wifiDatasource.connectToNetwork(network.ssid, password);
    return res.fold(
      (error) => Left(Failure(error.message)),
      (_) => Right(network),
    );
  }

  @override
  Future<Either<Failure, void>> disconnectFromNetwork(
    WifiNetwork network,
  ) async {
    final res = await _wifiDatasource.disconnect();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network) async {
    final res = await _wifiDatasource.forgetNetwork(network.ssid);
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, WifiNetwork>> getCurrentNetwork() async {
    return Right(
      WifiNetwork(ssid: 'RDE-Net', security: 'WPA2/WPA3', strength: '95%'),
    );
  }

  @override
  Future<Either<Failure, int>> getNetworkPriority(WifiNetwork network) async {
    return const Right(0);
  }

  @override
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks() async {
    final res = await _wifiDatasource.getSavedNetworks();
    return res.mapLeft((error) => Failure(error.message));
  }

  @override
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  ) async {
    return const Right(null);
  }
}
