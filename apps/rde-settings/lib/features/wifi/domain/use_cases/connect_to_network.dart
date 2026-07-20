import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class ConnectToNetworkUseCase {
  final WifiRepository _wifiRepository;

  const ConnectToNetworkUseCase(this._wifiRepository);

  Future<Either<Failure, WifiNetwork>> call(
    WifiNetwork network, {
    String? password,
  }) async {
    return _wifiRepository.connectToNetwork(network, password: password);
  }
}
