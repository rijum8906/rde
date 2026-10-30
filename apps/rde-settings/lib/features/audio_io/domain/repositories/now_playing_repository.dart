import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Domain port for the MPRIS players running on the session bus.
///
/// Implementations live in `data/repositories/`. The use cases depend on this
/// interface, not on the D-Bus proxy or its D-Bus types, and failures are
/// reported as a [Failure] value instead of thrown.
abstract interface class NowPlayingRepository {
  /// Emits whenever a player reports a new track or playback state, or when a
  /// player appears or disappears from the bus.
  Stream<void> watchChanges();

  /// Lists the players that own a name on the session bus.
  ///
  /// # Errors
  /// Returns a [Failure] when the session bus cannot be reached.
  Future<Either<Failure, List<NowPlayingMedia>>> getPlayers();

  /// Flips [media]'s player between playing and paused.
  ///
  /// # Errors
  /// Returns a [Failure] when the player is gone or refuses the call.
  Future<Either<Failure, void>> togglePlayPause(NowPlayingMedia media);

  /// Skips [media]'s player to the next track.
  ///
  /// # Errors
  /// Returns a [Failure] when the player is gone or refuses the call.
  Future<Either<Failure, void>> skipToNext(NowPlayingMedia media);

  /// Skips [media]'s player back to the previous track.
  ///
  /// # Errors
  /// Returns a [Failure] when the player is gone or refuses the call.
  Future<Either<Failure, void>> skipToPrevious(NowPlayingMedia media);
}
