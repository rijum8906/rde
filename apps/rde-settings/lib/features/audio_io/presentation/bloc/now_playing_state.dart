import 'package:equatable/equatable.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

enum NowPlayingStatus { initial, loading, success, failure }

class NowPlayingState extends Equatable {
  /// Sentinel that distinguishes "keep the value" from "clear it".
  static const Object _unset = Object();

  const NowPlayingState({
    this.status = NowPlayingStatus.initial,
    this.players = const [],
    this.activeBusName,
    this.errorMessage,
    this.isBusy = false,
  });

  final NowPlayingStatus status;

  /// Players on the session bus, ordered with the ones that are playing first.
  ///
  /// The order is what the slider pages through, so "prefer what is playing"
  /// is expressed here once instead of in every widget.
  final List<NowPlayingMedia> players;

  /// Bus name of the player the card currently shows, or `null` when no player
  /// is running.
  ///
  /// The selection is held by name rather than by index, because a refresh can
  /// reorder the list - the player that starts playing moves to the front - and
  /// the card must keep showing the player the user picked.
  final String? activeBusName;

  final String? errorMessage;

  /// Whether a transport action is in flight.
  final bool isBusy;

  /// Index of the selected player inside [players], falling back to the first
  /// one when the selection is gone.
  int get activeIndex {
    final index = players.indexWhere(
      (player) => player.busName == activeBusName,
    );
    return index >= 0 ? index : 0;
  }

  /// Player the card renders, or `null` when nothing is running.
  NowPlayingMedia? get active => players.isEmpty ? null : players[activeIndex];

  NowPlayingState copyWith({
    NowPlayingStatus? status,
    List<NowPlayingMedia>? players,
    Object? activeBusName = _unset,
    Object? errorMessage = _unset,
    bool? isBusy,
    bool clearError = false,
  }) {
    return NowPlayingState(
      status: status ?? this.status,
      players: players ?? this.players,
      activeBusName: identical(activeBusName, _unset)
          ? this.activeBusName
          : activeBusName as String?,
      errorMessage: clearError
          ? null
          : identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isBusy: isBusy ?? this.isBusy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    players,
    activeBusName,
    errorMessage,
    isBusy,
  ];
}
