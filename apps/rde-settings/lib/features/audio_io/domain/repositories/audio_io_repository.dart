import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_io_settings.dart';

abstract interface class AudioIoRepository {
  Either<Failure, AudioIoSettings> getSettings();
  Future<Either<Failure, void>> saveSettings(AudioIoSettings settings);
}
