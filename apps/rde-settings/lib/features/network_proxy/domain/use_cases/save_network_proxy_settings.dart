import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/network_proxy/domain/entities/network_proxy_settings.dart';
import 'package:rde_settings/features/network_proxy/domain/repositories/network_proxy_repository.dart';

class SaveNetworkProxySettingsUseCase {
  final NetworkProxyRepository _repository;

  const SaveNetworkProxySettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(NetworkProxySettings settings) async {
    return _repository.saveSettings(settings);
  }
}
