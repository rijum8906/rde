import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/engine_overrides/domain/entities/engine_overrides_settings.dart';

abstract interface class EngineOverridesRepository {
  Either<Failure, EngineOverridesSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(EngineOverridesSettings settings);
}
