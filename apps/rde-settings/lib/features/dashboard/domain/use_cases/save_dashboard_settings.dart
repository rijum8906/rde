import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/repositories/dashboard_repository.dart';

class SaveDashboardSettingsUseCase {
  final DashboardRepository _repository;

  const SaveDashboardSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(DashboardSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
