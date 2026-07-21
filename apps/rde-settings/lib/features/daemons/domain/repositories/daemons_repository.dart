import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/daemons/domain/entities/daemons_settings.dart';

abstract interface class DaemonsRepository {
  Either<Failure, DaemonsSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(DaemonsSettings settings);
}
