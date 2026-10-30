import 'package:equatable/equatable.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/skip_track.dart';

abstract class NowPlayingEvent extends Equatable {
  const NowPlayingEvent();

  @override
  List<Object?> get props => [];
}

class NowPlayingInitEvent extends NowPlayingEvent {
  const NowPlayingInitEvent();
}

/// Raised when a player reports a new track, a new playback state, or when a
/// player joins or leaves the bus.
///
/// The event carries no payload: the bloc reads the authoritative properties
/// back from the players when it handles the event.
class NowPlayingServiceChangedEvent extends NowPlayingEvent {
  const NowPlayingServiceChangedEvent();
}

/// Asks the bloc to read the players again.
///
/// A burst of player signals is collapsed into this event once it settles, so
/// the read happens inside an event handler that can await it instead of from
/// the debounce timer, whose emitter has already completed.
class NowPlayingRefreshEvent extends NowPlayingEvent {
  const NowPlayingRefreshEvent();
}

/// Shows the card of one player, chosen by swiping the slider or tapping one of
/// its dots.
class SelectPlayerEvent extends NowPlayingEvent {
  const SelectPlayerEvent(this.busName);

  final String busName;

  @override
  List<Object?> get props => [busName];
}

/// Raised by the bloc's own position ticker while a track is playing.
///
/// MPRIS never signals `Position`, so the card drives its progress bar from
/// this: the tick advances the position the last read reported, and the next
/// read corrects it again.
class NowPlayingTickEvent extends NowPlayingEvent {
  const NowPlayingTickEvent();
}

/// Flips the selected player between playing and paused.
class TogglePlayPauseEvent extends NowPlayingEvent {
  const TogglePlayPauseEvent();
}

/// Moves the selected player to the next or the previous track.
class NowPlayingSkipTrackEvent extends NowPlayingEvent {
  const NowPlayingSkipTrackEvent(this.direction);

  final SkipDirection direction;

  @override
  List<Object?> get props => [direction];
}
