import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class WifiRepositoryImpl implements WifiRepository {
  @override
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  }) {
    // TODO: implement connectToNetwork
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> disconnectFromNetwork(WifiNetwork network) {
    // TODO: implement disconnectFromNetwork
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network) {
    // TODO: implement forgetNetwork
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks() {
    // TODO: implement getAvailableNetworks
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, WifiNetwork>> getCurrentNetwork() {
    // TODO: implement getCurrentNetwork
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, int>> getNetworkPriority(WifiNetwork network) {
    // TODO: implement getNetworkPriority
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks() {
    // TODO: implement getSavedNetworks
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  ) {
    // TODO: implement setNetworkPriority
    throw UnimplementedError();
  }
}
