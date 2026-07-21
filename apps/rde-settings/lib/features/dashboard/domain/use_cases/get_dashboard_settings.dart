import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSettingsUseCase {
  final DashboardRepository _repository;

  const GetDashboardSettingsUseCase(this._repository);

  Future<Either<Failure, DashboardSettings>> call() async {
    return _repository.getSettings();
  }
}
