import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/servive/player_resolver.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/read_now_playing.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/skip_track.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/toggle_play_pause.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/watch_now_playing.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_state.dart';

/// Keeps the Audio I/O now-playing card in step with the MPRIS players.
///
/// The players own the state: the card never guesses the result of a transport
/// action, it reads the players again afterwards, and it reloads on every
/// signal so a track skipped from the player itself shows up here as well.
///
/// The bloc also owns the two pieces of time the card needs:
///
/// - a debounce over the burst of `PropertiesChanged` signals a single track
///   change produces, so the card reloads once per change, not once per
///   property; and
/// - a one-second ticker that advances the progress bar between reads, because
///   MPRIS does not signal `Position` and a seek is only corrected when the
///   next read arrives.
///
/// Duplicate MPRIS instances (a browser's own endpoint and the desktop bridge,
/// two YouTube Music tabs, …) are collapsed by [PlayerResolver] before the
/// order is chosen, so the slider pages by "what is actually playing" instead
/// of by "how many names the player happened to register."
class NowPlayingBloc extends Bloc<NowPlayingEvent, NowPlayingState> {
  NowPlayingBloc({
    required this._read,
    required this._watch,
    required this._togglePlayPause,
    required this._skipTrack,
    this._resolver = const PlayerResolver(),
  }) : super(const NowPlayingState()) {
    on<NowPlayingInitEvent>(_onInit);
    on<NowPlayingServiceChangedEvent>(_onServiceChanged);
    on<NowPlayingRefreshEvent>(_onRefresh);
    on<NowPlayingTickEvent>(_onTick);
    on<SelectPlayerEvent>(_onSelectPlayer);
    on<TogglePlayPauseEvent>(_onTogglePlayPause);
    on<NowPlayingSkipTrackEvent>(_onSkipTrackEvent);

    // A player can start, stop, or change track at any time — the user may be
    // driving it from the media keys — so the subscription starts with the
    // bloc instead of when the card is first built.
    _changes = _watch().listen(
      (_) => add(const NowPlayingServiceChangedEvent()),
      onError: (Object _) {
        // A player that quits mid-watch can surface an error on the merged
        // stream. The next read reconciles; there is nothing to report here.
      },
    );

    // Step 1: MPRIS does not signal `Position`, so the progress bar is
    // advanced here and corrected by every read.
    _positionTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const NowPlayingTickEvent()),
    );
  }

  final ReadNowPlayingUseCase _read;
  final WatchNowPlayingUseCase _watch;
  final TogglePlayPauseUseCase _togglePlayPause;
  final SkipTrackUseCase _skipTrack;
  final PlayerResolver _resolver;

  /// Live updates pushed by the players while the page is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of player signals into a single read.
  Timer? _changeDebounce;

  /// Advances the progress bar between reads.
  Timer? _positionTicker;

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    _positionTicker?.cancel();
    await _changes.cancel();
    return super.close();
  }

  Future<void> _onInit(
    NowPlayingInitEvent event,
    Emitter<NowPlayingState> emit,
  ) async {
    emit(state.copyWith(status: NowPlayingStatus.loading, clearError: true));
    await _readPlayers(emit);
  }

  /// Collapses a burst of player signals into a single read.
  ///
  /// One track change produces several signals — the metadata, the length,
  /// the playback status — so the read waits for the burst to settle. The card
  /// keeps showing its current track until then, and a transport action in
  /// flight is left alone because it reads the players when it finishes.
  ///
  /// The timer only dispatches [NowPlayingRefreshEvent]: this handler returns
  /// synchronously, so its emitter is already completed by the time the timer
  /// fires, and the read is awaited by the refresh handler instead.
  void _onServiceChanged(
    NowPlayingServiceChangedEvent event,
    Emitter<NowPlayingState> emit,
  ) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 350), () {
      // `state` is a getter on the bloc, so this reads the bloc's *current*
      // state at the moment the timer fires, not the snapshot taken when
      // the handler started.
      if (state.isBusy) {
        return;
      }
      add(const NowPlayingRefreshEvent());
    });
  }

  Future<void> _onRefresh(
    NowPlayingRefreshEvent event,
    Emitter<NowPlayingState> emit,
  ) async {
    await _readPlayers(emit);
  }

  /// Moves the progress bar of the playing track one second forward.
  ///
  /// Only the selected player is advanced, only while it is playing, and only
  /// up to the length it reported: a paused player's bar stands still and a
  /// finished track does not run past its end. The read that follows any signal
  /// replaces the estimate with the player's own `Position`, so a seek or a
  /// drift is corrected instead of accumulated.
  void _onTick(NowPlayingTickEvent event, Emitter<NowPlayingState> emit) {
    final media = state.active;
    if (media == null ||
        state.isBusy ||
        !media.hasProgress ||
        !media.isPlaying) {
      return;
    }

    final length = media.length!;
    final position = media.position!;
    if (position >= length) {
      return;
    }

    final advanced = position + const Duration(seconds: 1);
    emit(
      state.copyWith(
        players: _withPosition(
          state.players,
          state.activeIndex,
          advanced > length ? length : advanced,
        ),
      ),
    );
  }

  /// Replaces the position of one player, leaving the others untouched.
  List<NowPlayingMedia> _withPosition(
    List<NowPlayingMedia> players,
    int index,
    Duration position,
  ) {
    return [
      for (var i = 0; i < players.length; i++)
        if (i == index) players[i].copyWith(position: position) else players[i],
    ];
  }

  void _onSelectPlayer(SelectPlayerEvent event, Emitter<NowPlayingState> emit) {
    if (event.busName == state.activeBusName) {
      return;
    }
    // A swipe can outrun a refresh, so a player that is no longer on the bus
    // is ignored instead of selecting an empty card.
    if (!state.players.any((player) => player.busName == event.busName)) {
      return;
    }
    emit(state.copyWith(activeBusName: event.busName));
  }

  Future<void> _onTogglePlayPause(
    TogglePlayPauseEvent event,
    Emitter<NowPlayingState> emit,
  ) async {
    final media = state.active;
    if (media == null || !media.canTogglePlayback || state.isBusy) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await _togglePlayPause(media));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _readPlayers(emit, isBusy: false);
  }

  Future<void> _onSkipTrackEvent(
    NowPlayingSkipTrackEvent event,
    Emitter<NowPlayingState> emit,
  ) async {
    final media = state.active;
    if (media == null || state.isBusy) {
      return;
    }

    final canSkip = event.direction == SkipDirection.next
        ? media.canSkipNext
        : media.canSkipPrevious;
    if (!canSkip) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final failure = _failureOf(await _skipTrack(media, event.direction));
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _readPlayers(emit, isBusy: false);
  }

  /// Reads the players back and republishes the card.
  ///
  /// A failed read keeps the track the card already shows and only reports the
  /// error, because a player quitting mid-read should not blank the card for
  /// the players that are still running.
  Future<void> _readPlayers(
    Emitter<NowPlayingState> emit, {
    bool? isBusy,
  }) async {
    final result = await _read();
    Failure? failure;
    List<NowPlayingMedia>? raw;
    result.fold((value) => failure = value, (value) => raw = value);

    if (failure != null) {
      emit(
        state.copyWith(
          status: state.status == NowPlayingStatus.loading
              ? NowPlayingStatus.failure
              : state.status,
          errorMessage: failure!.message,
          isBusy: isBusy,
        ),
      );
      return;
    }

    // Collapse duplicate MPRIS instances (two YouTube Music tabs, a browser's
    // own endpoint + the desktop bridge, etc.) into one card per distinct
    // playback session, with capabilities OR-ed across the group.
    final resolved = _resolver.resolve(raw!);

    final ordered = _ordered(resolved, state.players);
    emit(
      state.copyWith(
        status: NowPlayingStatus.success,
        players: ordered,
        activeBusName: _selection(ordered),
        clearError: true,
        isBusy: isBusy,
      ),
    );
  }

  /// Decide what order the cards are shown in.
  ///
  /// The order is chosen once per visit, from the first read after the page was
  /// opened: players that are playing lead, and within that, the players that
  /// publish cover art lead, because a browser's own MPRIS endpoint often
  /// reports the same track as the desktop's bridge with no artwork at all.
  /// Bus name breaks ties, so the choice does not drift between reads.
  ///
  /// Every later read keeps the order that was already published and only
  /// refreshes what each card says. Re-ranking on every read would move the
  /// slider under the user: pausing the player at the front would make the next
  /// one jump into its place.
  List<NowPlayingMedia> _ordered(
    List<NowPlayingMedia> players,
    List<NowPlayingMedia> previous,
  ) {
    // Step 1: The first read of the visit ranks the players.
    if (previous.isEmpty) {
      return players.toList()..sort((a, b) {
        final byRank = _rank(a).compareTo(_rank(b));
        return byRank != 0 ? byRank : a.busName.compareTo(b.busName);
      });
    }

    // Step 2: Later reads keep the published order, taking each player's fresh
    // values and dropping the ones that left the bus.
    final fresh = {for (final player in players) player.busName: player};
    final ordered = <NowPlayingMedia>[];
    for (final player in previous) {
      final updated = fresh.remove(player.busName);
      if (updated != null) {
        ordered.add(updated);
      }
    }

    // Step 3: A player that appeared during the visit has no place in the
    // order yet, so it joins the end instead of pushing itself to the front.
    ordered.addAll(fresh.values);
    return ordered;
  }

  /// Rank used when the page is opened: playing first, then cover art.
  int _rank(NowPlayingMedia media) {
    return (media.isPlaying ? 0 : 2) + (media.hasArtwork ? 0 : 1);
  }

  /// Player to show after a read: the one the user is looking at while it is
  /// still on the bus, otherwise the preferred one.
  String? _selection(List<NowPlayingMedia> players) {
    final current = state.activeBusName;
    if (current != null && players.any((player) => player.busName == current)) {
      return current;
    }
    return players.isEmpty ? null : players.first.busName;
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
