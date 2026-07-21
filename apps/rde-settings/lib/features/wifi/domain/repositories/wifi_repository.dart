import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

abstract interface class WifiRepository {
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks();
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  });
  Future<Either<Failure, void>> disconnectFromNetwork(WifiNetwork network);
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network);
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks();
  Future<Either<Failure, WifiNetwork>> getCurrentNetwork();
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  );
  Future<Either<Failure, int>> getNetworkPriority(WifiNetwork network);
}
