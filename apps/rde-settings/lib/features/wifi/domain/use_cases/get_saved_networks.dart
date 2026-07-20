import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';

class GetSavedNetworksUseCase {
  final WifiRepository _wifiRepository;

  const GetSavedNetworksUseCase(this._wifiRepository);

  Future<Either<Failure, List<WifiNetwork>>> call() async {
    return _wifiRepository.getSavedNetworks();
  }
}
