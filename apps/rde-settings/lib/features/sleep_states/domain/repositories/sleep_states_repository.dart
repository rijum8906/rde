import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/sleep_states/domain/entities/sleep_states_settings.dart';

abstract interface class SleepStatesRepository {
  Either<Failure, SleepStatesSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(SleepStatesSettings settings);
}
