import 'package:equatable/equatable.dart';

/// Playback state a player reports through `PlaybackStatus`.
///
/// MPRIS has exactly these three states; anything a player reports that is not
/// one of them is treated as [stopped].
enum MprisPlaybackStatus { playing, paused, stopped }

/// One MPRIS player and what it is currently playing.
///
/// The entity mirrors the subset of `org.mpris.MediaPlayer2.Player` the Audio
/// I/O page renders. Everything except [busName], [playerName], and [status] is
/// optional, because players publish different subsets of the interface: a
/// browser tab may report only a title, and `Metadata` is empty for a player
/// that has not loaded a track yet.
class NowPlayingMedia extends Equatable {
  const NowPlayingMedia({
    required this.busName,
    required this.playerName,
    required this.status,
    required this.title,
    required this.artists,
    required this.album,
    required this.artUrl,
    required this.length,
    required this.position,
    required this.canControl,
    required this.canPlay,
    required this.canPause,
    required this.canGoNext,
    required this.canGoPrevious,
  });

  /// Well-known bus name the player owns, e.g.
  /// `org.mpris.MediaPlayer2.spotify`.
  ///
  /// This is also the address every transport call is sent to, so it identifies
  /// the player whose card the user is looking at.
  final String busName;

  /// Name a user recognizes: the player's `Identity`, or its bus name when the
  /// player does not publish one.
  final String playerName;

  /// Whether the player is playing, paused, or stopped.
  final MprisPlaybackStatus status;

  /// `xesam:title`, or `null` when the player reports no metadata.
  final String? title;

  /// `xesam:artist`, empty when the player reports none.
  final List<String> artists;

  /// `xesam:album`, or `null` when the player reports no metadata.
  final String? album;

  /// `mpris:artUrl`, usually a `file://` URI to a cached cover and occasionally
  /// an `http(s)` one.
  final String? artUrl;

  /// `mpris:length` in microseconds, or `null` when the player reports none.
  final Duration? length;

  /// `Position` in microseconds, or `null` when the player reports none.
  ///
  /// MPRIS deliberately does not signal `Position` - it only sends `Seeked` -
  /// so this is the position the player reported at the last read. The bloc
  /// advances it between reads while the track is playing, which is what makes
  /// the progress bar move.
  final Duration? position;

  /// `CanControl`: whether the player accepts method calls at all.
  final bool canControl;

  /// `CanPlay` / `CanPause`: whether playback can be started and suspended.
  final bool canPlay;
  final bool canPause;

  /// `CanGoNext` / `CanGoPrevious`: whether the player has a queue to move
  /// through. A single-track player reports `false`, so the buttons are
  /// disabled instead of failing when pressed.
  final bool canGoNext;
  final bool canGoPrevious;

  bool get isPlaying => status == MprisPlaybackStatus.playing;

  /// Whether the player reports a track the card can name.
  bool get hasTrack => title != null && title!.isNotEmpty;

  /// Whether the play/pause button does anything.
  ///
  /// A player with `CanControl = false` ignores every call, and one that can
  /// neither play nor pause has nothing to toggle.
  bool get canTogglePlayback => canControl && (canPlay || canPause);

  bool get canSkipNext => canControl && canGoNext;
  bool get canSkipPrevious => canControl && canGoPrevious;

  /// Whether the card can draw how far into the track the player is.
  bool get hasProgress => length != null && position != null;

  /// Whether the player published cover art the card can paint.
  ///
  /// Not every player has artwork: a browser's own MPRIS endpoint frequently
  /// reports none, while the desktop's browser bridge reports the same track
  /// with a cover. The ordering of the cards and the backdrop both care, so it
  /// is answered here instead of in each widget.
  bool get hasArtwork => artUrl != null && artUrl!.isNotEmpty;

  /// Artist line shown under the title.
  String get artistLabel =>
      artists.isEmpty ? 'Unknown artist' : artists.join(', ');

  /// One-word label for the playback state.
  String get statusLabel {
    switch (status) {
      case MprisPlaybackStatus.playing:
        return 'Playing';
      case MprisPlaybackStatus.paused:
        return 'Paused';
      case MprisPlaybackStatus.stopped:
        return 'Stopped';
    }
  }

  /// Track length as `m:ss`, or `null` when the player reports none.
  String? get lengthLabel {
    final total = length;
    if (total == null || total.inSeconds <= 0) {
      return null;
    }
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Copy with a new [position].
  ///
  /// Used by the bloc to advance the progress bar between daemon reads; every
  /// other field belongs to the player and is only ever replaced by a read.
  NowPlayingMedia copyWith({
    String? busName,
    String? playerName,
    MprisPlaybackStatus? status,
    String? title,
    List<String>? artists,
    String? album,
    String? artUrl,
    Duration? length,
    Duration? position,
    bool? canControl,
    bool? canPlay,
    bool? canPause,
    bool? canGoNext,
    bool? canGoPrevious,
  }) {
    return NowPlayingMedia(
      busName: busName ?? this.busName,
      playerName: playerName ?? this.playerName,
      status: status ?? this.status,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      artUrl: artUrl ?? this.artUrl,
      length: length ?? this.length,
      position: position ?? this.position,
      canControl: canControl ?? this.canControl,
      canPlay: canPlay ?? this.canPlay,
      canPause: canPause ?? this.canPause,
      canGoNext: canGoNext ?? this.canGoNext,
      canGoPrevious: canGoPrevious ?? this.canGoPrevious,
    );
  }

  // in now_playing_media.dart, after copyWith

  /// Copy with the capabilities and metadata the [PlayerResolver] merges.
  ///
  /// Every argument is `required` so the resolver passes the computed value
  /// directly, including `null` for fields the group has no value for. The
  /// generic `copyWith` pattern cannot express "set this field to null",
  /// which is why this method exists.
  NowPlayingMedia copyWithMerged({
    required bool canControl,
    required bool canPlay,
    required bool canPause,
    required bool canGoNext,
    required bool canGoPrevious,
    required String? artUrl,
    required String? album,
    required Duration? position,
    required Duration? length,
  }) {
    return NowPlayingMedia(
      busName: busName,
      playerName: playerName,
      status: status,
      title: title,
      artists: artists,
      album: album,
      artUrl: artUrl,
      length: length,
      position: position,
      canControl: canControl,
      canPlay: canPlay,
      canPause: canPause,
      canGoNext: canGoNext,
      canGoPrevious: canGoPrevious,
    );
  }

  @override
  List<Object?> get props => [
    busName,
    playerName,
    status,
    title,
    artists,
    album,
    artUrl,
    length,
    position,
    canControl,
    canPlay,
    canPause,
    canGoNext,
    canGoPrevious,
  ];
}
