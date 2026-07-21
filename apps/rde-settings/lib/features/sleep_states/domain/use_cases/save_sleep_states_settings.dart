import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/sleep_states/domain/entities/sleep_states_settings.dart';
import 'package:rde_settings/features/sleep_states/domain/repositories/sleep_states_repository.dart';

class SaveSleepStatesSettingsUseCase {
  final SleepStatesRepository _repository;

  const SaveSleepStatesSettingsUseCase(this._repository);

  Future<Either<Failure, void>> call(SleepStatesSettings settings) async {
    return _repository.saveSettings(settings);
  }
}
