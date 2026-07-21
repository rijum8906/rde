import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class GetCurrentNetworkUseCase {
  final WifiRepository _wifiRepository;

  const GetCurrentNetworkUseCase(this._wifiRepository);

  Future<Either<Failure, WifiNetwork>> call() async {
    return _wifiRepository.getCurrentNetwork();
  }
}
