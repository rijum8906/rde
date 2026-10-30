import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_io_settings.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_io_repository.dart';

class GetAudioIoSettingsUseCase {
  final AudioIoRepository _repository;

  const GetAudioIoSettingsUseCase(this._repository);

  Future<Either<Failure, AudioIoSettings>> call() async {
    return _repository.getSettings();
  }
}
