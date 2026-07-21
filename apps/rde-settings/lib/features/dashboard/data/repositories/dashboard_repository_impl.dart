import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardSettings _settings = const DashboardSettings(
    isDarkMode: true,
    isWifiEnabled: true,
    isBluetoothEnabled: false,
    isDndEnabled: false,
    batteryLevel: 0.88,
    ramUsage: 0.54,
    storageUsage: 0.38,
  );

  @override
  Either<Failure, DashboardSettings> getSettings() {
    return Right(_settings);
  }

  @override
  Future<Either<Failure, void>> saveSettings(DashboardSettings settings) async {
    _settings = settings;
    return const Right(null);
  }
}
