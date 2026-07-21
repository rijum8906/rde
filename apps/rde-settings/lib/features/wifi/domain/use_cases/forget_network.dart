import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class ForgetNetworkUseCase {
  final WifiRepository _wifiRepository;

  const ForgetNetworkUseCase(this._wifiRepository);

  Future<Either<Failure, void>> call(WifiNetwork network) async {
    return _wifiRepository.forgetNetwork(network);
  }
}
