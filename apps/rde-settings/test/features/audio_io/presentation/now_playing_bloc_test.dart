import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/now_playing_repository.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/read_now_playing.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/skip_track.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/toggle_play_pause.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/watch_now_playing.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_state.dart';

const String _spotify = 'org.mpris.MediaPlayer2.spotify';
const String _vlc = 'org.mpris.MediaPlayer2.vlc';
const String _chrome = 'org.mpris.MediaPlayer2.chromium.instance1';

/// Cover art a player can publish; the card paints whatever URL it is given.
const String _artUrl = 'file:///home/user/.cache/cover.png';

NowPlayingMedia _media({
  required String busName,
  required String title,
  MprisPlaybackStatus status = MprisPlaybackStatus.playing,
  bool canGoNext = true,
  bool canGoPrevious = true,
  Duration? position = const Duration(seconds: 30),
  String? artUrl = _artUrl,
}) {
  return NowPlayingMedia(
    busName: busName,
    playerName: busName.split('.').last,
    status: status,
    title: title,
    artists: const ['Kavinsky'],
    album: 'OutRun',
    artUrl: artUrl,
    length: const Duration(minutes: 3, seconds: 34),
    position: position,
    canControl: true,
    canPlay: true,
    canPause: true,
    canGoNext: canGoNext,
    canGoPrevious: canGoPrevious,
  );
}

/// In-memory stand-in for the MPRIS-backed repository.
///
/// The players are the bus state: a transport call writes them, so a following
/// read observes the change exactly like the real players behave.
class _FakeNowPlayingRepository implements NowPlayingRepository {
  List<NowPlayingMedia> players = [];
  bool failRead = false;

  int toggleCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;

  /// Stands in for the MPRIS signal stream.
  final StreamController<void> changes = StreamController<void>.broadcast();

  /// Pretends a player pushed a new track or playback state.
  void notifyChange() => changes.add(null);

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<Either<Failure, List<NowPlayingMedia>>> getPlayers() async {
    if (failRead) {
      return Left(Failure('Could not read the media players'));
    }
    return Right(players);
  }

  @override
  Future<Either<Failure, void>> togglePlayPause(NowPlayingMedia media) async {
    toggleCalls += 1;
    players = [
      for (final player in players)
        if (player.busName == media.busName)
          _media(
            busName: player.busName,
            title: player.title!,
            status: player.isPlaying
                ? MprisPlaybackStatus.paused
                : MprisPlaybackStatus.playing,
            canGoNext: player.canGoNext,
            canGoPrevious: player.canGoPrevious,
            position: player.position,
            artUrl: player.artUrl,
          )
        else
          player,
    ];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> skipToNext(NowPlayingMedia media) async {
    nextCalls += 1;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> skipToPrevious(NowPlayingMedia media) async {
    previousCalls += 1;
    return const Right(null);
  }
}

NowPlayingBloc _bloc(NowPlayingRepository repository) {
  return NowPlayingBloc(
    read: ReadNowPlayingUseCase(repository),
    watch: WatchNowPlayingUseCase(repository),
    togglePlayPause: TogglePlayPauseUseCase(repository),
    skipTrack: SkipTrackUseCase(repository),
  );
}

Future<void> _init(NowPlayingBloc bloc) {
  bloc.add(const NowPlayingInitEvent());
  return bloc.stream.firstWhere(
    (value) => value.status == NowPlayingStatus.success,
  );
}

void main() {
  test(
    'init opens on a playing player, not just the first on the bus',
    () async {
      final repository = _FakeNowPlayingRepository()
        ..players = [
          _media(
            busName: _vlc,
            title: 'Stopped track',
            status: MprisPlaybackStatus.paused,
          ),
          _media(busName: _spotify, title: 'Nightcall'),
        ];
      final bloc = _bloc(repository);

      await _init(bloc);
      final state = bloc.state;

      expect(state.players.first.busName, _spotify);
      expect(state.active?.busName, _spotify);
      expect(state.active?.title, 'Nightcall');
      expect(state.activeIndex, 0);

      await bloc.close();
    },
  );

  test('a player signal refreshes the card after the burst settles', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);

    // The player moves to the next track; the card has to follow without a
    // reload.
    repository.players = [_media(busName: _spotify, title: 'Odd Look')];
    final refreshed = bloc.stream.firstWhere(
      (value) => value.active?.title == 'Odd Look',
    );
    repository.notifyChange();

    final state = await refreshed;

    expect(state.active?.busName, _spotify);
    expect(state.errorMessage, isNull);

    await bloc.close();
  });

  test(
    'opening the page leads with a playing player that has artwork',
    () async {
      final repository = _FakeNowPlayingRepository()
        ..players = [
          // The browser's own endpoint, playing but with nothing to show.
          _media(busName: _chrome, title: 'Hass Hass', artUrl: null),
          // The desktop bridge for the same track, artwork included.
          _media(busName: _vlc, title: 'Hass Hass'),
          _media(
            busName: _spotify,
            title: 'Nightcall',
            status: MprisPlaybackStatus.paused,
          ),
        ];
      final bloc = _bloc(repository);

      await _init(bloc);

      expect(bloc.state.players.map((player) => player.busName).toList(), [
        _vlc,
        _chrome,
        _spotify,
      ]);
      expect(bloc.state.active?.busName, _vlc);
      expect(bloc.state.active?.hasArtwork, isTrue);

      await bloc.close();
    },
  );

  test('pausing the leading player does not reorder the slider', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [
        _media(busName: _chrome, title: 'Hass Hass', artUrl: null),
        _media(busName: _vlc, title: 'Hass Hass'),
      ];
    final bloc = _bloc(repository);

    await _init(bloc);
    expect(bloc.state.players.map((player) => player.busName).toList(), [
      _vlc,
      _chrome,
    ]);

    // The leading player pauses. The order was decided when the page opened,
    // so nothing moves; the card keeps showing the player it was showing.
    repository.players = [
      _media(busName: _chrome, title: 'Hass Hass', artUrl: null),
      _media(
        busName: _vlc,
        title: 'Hass Hass',
        status: MprisPlaybackStatus.paused,
      ),
    ];
    bloc.add(const NowPlayingRefreshEvent());
    await bloc.stream.firstWhere(
      (value) =>
          value.players.first.busName == _vlc &&
          value.players.first.status == MprisPlaybackStatus.paused,
    );

    expect(bloc.state.players.map((player) => player.busName).toList(), [
      _vlc,
      _chrome,
    ]);
    expect(bloc.state.active?.busName, _vlc);

    await bloc.close();
  });

  test('a player that appears during the visit joins the end', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);

    repository.players = [
      _media(busName: _spotify, title: 'Nightcall'),
      _media(busName: _vlc, title: 'Odd Look'),
    ];
    bloc.add(const NowPlayingRefreshEvent());
    await bloc.stream.firstWhere((value) => value.players.length == 2);

    // It is playing, but the order was fixed when the page opened, so it does
    // not push itself ahead of a player the user may already be looking at.
    expect(bloc.state.players.last.busName, _vlc);
    expect(bloc.state.active?.busName, _spotify);

    await bloc.close();
  });

  test('play/pause reads the player back instead of guessing', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);

    final toggled = bloc.stream.firstWhere(
      (value) => value.active?.status == MprisPlaybackStatus.paused,
    );
    bloc.add(const TogglePlayPauseEvent());
    final state = await toggled;

    expect(repository.toggleCalls, 1);
    expect(state.isBusy, isFalse);

    await bloc.close();
  });

  test(
    'a failed toggle reports the error and leaves the card usable',
    () async {
      final repository = _FakeNowPlayingRepository()
        ..players = [_media(busName: _spotify, title: 'Nightcall')];
      final bloc = _bloc(repository);

      await _init(bloc);
      repository.failRead = true;

      final failed = bloc.stream.firstWhere(
        (value) => value.errorMessage != null,
      );
      bloc.add(const TogglePlayPauseEvent());
      final state = await failed;

      expect(repository.toggleCalls, 1);
      expect(state.isBusy, isFalse);
      // The track the card was showing is still there.
      expect(state.active?.title, 'Nightcall');

      await bloc.close();
    },
  );

  test('skip moves in the direction that was asked for', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);

    // Each wait has to end on the settled state: a transport action in flight
    // ignores the next one, so only waiting for the call is not enough.
    bloc.add(const NowPlayingSkipTrackEvent(SkipDirection.next));
    await bloc.stream.firstWhere(
      (value) => !value.isBusy && repository.nextCalls == 1,
    );

    bloc.add(const NowPlayingSkipTrackEvent(SkipDirection.previous));
    await bloc.stream.firstWhere(
      (value) => !value.isBusy && repository.previousCalls == 1,
    );

    expect(repository.nextCalls, 1);
    expect(repository.previousCalls, 1);

    await bloc.close();
  });

  test('a player that cannot skip is never asked to', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [
        _media(
          busName: _spotify,
          title: 'Single track',
          canGoNext: false,
          canGoPrevious: false,
        ),
      ];
    final bloc = _bloc(repository);

    await _init(bloc);
    bloc.add(const NowPlayingSkipTrackEvent(SkipDirection.next));
    await Future<void>.delayed(Duration.zero);

    expect(repository.nextCalls, 0);

    await bloc.close();
  });

  test('a failed read keeps the card and reports the error', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);
    repository.failRead = true;

    final failed = bloc.stream.firstWhere(
      (value) => value.errorMessage != null,
    );
    bloc.add(const NowPlayingRefreshEvent());
    final state = await failed;

    expect(state.active?.title, 'Nightcall');
    expect(state.errorMessage, isNotNull);

    await bloc.close();
  });

  test('no player on the bus is an empty card, not an error', () async {
    final bloc = _bloc(_FakeNowPlayingRepository());

    await _init(bloc);

    expect(bloc.state.players, isEmpty);
    expect(bloc.state.active, isNull);
    expect(bloc.state.errorMessage, isNull);

    await bloc.close();
  });

  test('the progress bar advances while the track plays', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [_media(busName: _spotify, title: 'Nightcall')];
    final bloc = _bloc(repository);

    await _init(bloc);
    expect(bloc.state.active?.position, const Duration(seconds: 30));

    // MPRIS never signals Position, so the ticker is what moves the bar.
    final advanced = bloc.stream.firstWhere(
      (value) => value.active?.position == const Duration(seconds: 31),
    );
    final state = await advanced;

    expect(state.active?.position, const Duration(seconds: 31));
    expect(state.active?.length, const Duration(minutes: 3, seconds: 34));

    await bloc.close();
  });

  test('the progress bar stands still while the player is paused', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [
        _media(
          busName: _spotify,
          title: 'Nightcall',
          status: MprisPlaybackStatus.paused,
        ),
      ];
    final bloc = _bloc(repository);

    await _init(bloc);

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    expect(bloc.state.active?.position, const Duration(seconds: 30));

    await bloc.close();
  });

  test('a player that reports no position has nothing to advance', () async {
    final repository = _FakeNowPlayingRepository()
      ..players = [
        _media(busName: _spotify, title: 'Nightcall', position: null),
      ];
    final bloc = _bloc(repository);

    await _init(bloc);

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    expect(bloc.state.active?.position, isNull);

    await bloc.close();
  });

  test('leaving the page stops listening for player signals', () async {
    final repository = _FakeNowPlayingRepository();
    final bloc = _bloc(repository);

    await _init(bloc);
    expect(repository.changes.hasListener, isTrue);

    await bloc.close();

    expect(repository.changes.hasListener, isFalse);
  });
}
