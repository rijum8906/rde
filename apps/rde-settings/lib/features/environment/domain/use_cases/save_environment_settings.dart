import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/environment/domain/entities/environment_settings.dart';
import 'package:rde_settings/features/environment/domain/repositories/environment_repository.dart';

class SaveEnvironmentSettingsUseCase {
  final EnvironmentRepository _repository;

  const SaveEnvironmentSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(EnvironmentSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
