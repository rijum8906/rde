import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class SetNetworkPriorityUseCase {
  final WifiRepository _wifiRepository;

  const SetNetworkPriorityUseCase(this._wifiRepository);

  Future<Either<Failure, void>> call(WifiNetwork network, int priority) async {
    return _wifiRepository.setNetworkPriority(network, priority);
  }
}
