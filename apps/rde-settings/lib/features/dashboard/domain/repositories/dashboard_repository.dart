import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';

abstract interface class DashboardRepository {
  Either<Failure, DashboardSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(DashboardSettings settings);
}
