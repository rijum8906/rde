import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/sleep_states/domain/entities/sleep_states_settings.dart';
import 'package:rde_settings/features/sleep_states/domain/repositories/sleep_states_repository.dart';

class GetSleepStatesSettingsUseCase {
  final SleepStatesRepository _repository;

  const GetSleepStatesSettingsUseCase(this._repository);

  Future<Either<Failure, SleepStatesSettings>> call() async {
    return _repository.getSettings();
  }
}
