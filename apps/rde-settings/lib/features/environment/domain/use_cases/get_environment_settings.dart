import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/environment/domain/entities/environment_settings.dart';
import 'package:rde_settings/features/environment/domain/repositories/environment_repository.dart';

class GetEnvironmentSettingsUseCase {
  final EnvironmentRepository _repository;

  const GetEnvironmentSettingsUseCase(this._repository);

  Future<Either<Failure, EnvironmentSettings>> call() async {
    return _repository.getSettings();
  }
}
