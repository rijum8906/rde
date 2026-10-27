import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

abstract interface class WifiRepository {
  /// Emits whenever NetworkManager reports a change the page has to show.
  Stream<void> watchChanges();
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks();
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  });
  Future<Either<Failure, void>> disconnectFromNetwork(WifiNetwork network);
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network);
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks();
  Future<Either<Failure, WifiNetwork?>> getCurrentNetwork();
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  );
  Future<Either<Failure, int>> getNetworkPriority(WifiNetwork network);
  Future<Either<Failure, bool>> isWifiEnabled();
  Future<Either<Failure, void>> setWifiEnabled(bool enabled);
}
