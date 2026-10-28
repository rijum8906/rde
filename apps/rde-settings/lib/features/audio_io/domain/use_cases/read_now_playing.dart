import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';

/// Lists the media players that are running.
class ReadNowPlayingUseCase {
  final NowPlayingRepository _repository;

  const ReadNowPlayingUseCase(this._repository);

  Future<Either<Failure, List<NowPlayingMedia>>> call() {
    return _repository.getPlayers();
  }
}
