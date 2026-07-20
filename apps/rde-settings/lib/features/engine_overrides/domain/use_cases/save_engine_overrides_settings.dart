import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/engine_overrides/domain/entities/engine_overrides_settings.dart';
import 'package:rde_settings/features/engine_overrides/domain/repositories/engine_overrides_repository.dart';

class SaveEngineOverridesSettingsUseCase {
  final EngineOverridesRepository _repository;

  const SaveEngineOverridesSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(EngineOverridesSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
