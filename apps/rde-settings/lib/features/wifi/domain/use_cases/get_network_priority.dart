import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class GetNetworkPriorityUseCase {
  final WifiRepository _wifiRepository;

  const GetNetworkPriorityUseCase(this._wifiRepository);

  Future<Either<Failure, int>> call(WifiNetwork network) async {
    return _wifiRepository.getNetworkPriority(network);
  }
}
