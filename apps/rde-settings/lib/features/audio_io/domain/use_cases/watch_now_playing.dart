import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';

/// Emits one event per track, playback-state, or player-list change the card
/// has to reload.
class WatchNowPlayingUseCase {
  const WatchNowPlayingUseCase(this._repository);

  final NowPlayingRepository _repository;

  Stream<void> call() => _repository.watchChanges();
}
