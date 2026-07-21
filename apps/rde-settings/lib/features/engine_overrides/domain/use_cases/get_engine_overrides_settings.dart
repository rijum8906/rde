import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/engine_overrides/domain/entities/engine_overrides_settings.dart';
import 'package:rde_settings/features/engine_overrides/domain/repositories/engine_overrides_repository.dart';

class GetEngineOverridesSettingsUseCase {
  final EngineOverridesRepository _repository;

  const GetEngineOverridesSettingsUseCase(this._repository);

  Future<Either<Failure, EngineOverridesSettings>> call() async {
    return _repository.getSettings();
  }
}
