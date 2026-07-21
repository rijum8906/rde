import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/network_proxy/domain/entities/network_proxy_settings.dart';

abstract interface class NetworkProxyRepository {
  Either<Failure, NetworkProxySettings> getSettings();
  Future<Either<Failure, void>> saveSettings(NetworkProxySettings settings);
}
