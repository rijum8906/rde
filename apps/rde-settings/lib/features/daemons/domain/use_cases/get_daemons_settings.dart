import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/daemons/domain/entities/daemons_settings.dart';
import 'package:rde_settings/features/daemons/domain/repositories/daemons_repository.dart';

class GetDaemonsSettingsUseCase {
  final DaemonsRepository _repository;

  const GetDaemonsSettingsUseCase(this._repository);

  Future<Either<Failure, DaemonsSettings>> call() async {
    return _repository.getSettings();
  }
}
