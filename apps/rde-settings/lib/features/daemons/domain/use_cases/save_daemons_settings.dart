import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/daemons/domain/entities/daemons_settings.dart';
import 'package:rde_settings/features/daemons/domain/repositories/daemons_repository.dart';

class SaveDaemonsSettingsUseCase {
  final DaemonsRepository _repository;

  const SaveDaemonsSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(DaemonsSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
