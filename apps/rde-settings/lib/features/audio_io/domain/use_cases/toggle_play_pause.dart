import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';

/// Flips one player between playing and paused.
///
/// MPRIS exposes a single toggle rather than separate play and pause calls, so
/// the card renders the button from the state the player reports and asks the
/// player to switch.
class TogglePlayPauseUseCase {
  final NowPlayingRepository _repository;

  const TogglePlayPauseUseCase(this._repository);

  Future<Either<Failure, void>> call(NowPlayingMedia media) {
    return _repository.togglePlayPause(media);
  }
}
