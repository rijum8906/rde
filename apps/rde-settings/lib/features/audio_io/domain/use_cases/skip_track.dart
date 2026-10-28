import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';

/// Direction a skip moves through the player's queue.
enum SkipDirection { next, previous }

/// Moves one player to the next or the previous track.
class SkipTrackUseCase {
  final NowPlayingRepository _repository;

  const SkipTrackUseCase(this._repository);

  Future<Either<Failure, void>> call(
    NowPlayingMedia media,
    SkipDirection direction,
  ) {
    switch (direction) {
      case SkipDirection.next:
        return _repository.skipToNext(media);
      case SkipDirection.previous:
        return _repository.skipToPrevious(media);
    }
  }
}
