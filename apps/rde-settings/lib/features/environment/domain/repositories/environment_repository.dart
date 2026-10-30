import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/environment/domain/entities/environment_settings.dart';

abstract interface class EnvironmentRepository {
  Either<Failure, EnvironmentSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(EnvironmentSettings settings);
}
