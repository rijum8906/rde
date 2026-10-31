import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/audio_devices_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_slider.dart';

const String _spotify = 'org.mpris.MediaPlayer2.spotify';
const String _vlc = 'org.mpris.MediaPlayer2.vlc';

NowPlayingMedia _media({
  required String busName,
  required String playerName,
  required String title,
}) {
  return NowPlayingMedia(
    busName: busName,
    playerName: playerName,
    status: MprisPlaybackStatus.playing,
    title: title,
    artists: const ['Kavinsky'],
    album: 'OutRun',
    artUrl: null,
    length: const Duration(minutes: 3),
    position: const Duration(seconds: 30),
    canControl: true,
    canPlay: true,
    canPause: true,
    canGoNext: true,
    canGoPrevious: true,
  );
}

final _spotifyTrack = _media(
  busName: _spotify,
  playerName: 'Spotify',
  title: 'Nightcall',
);
final _vlcTrack = _media(busName: _vlc, playerName: 'vlc', title: 'Odd Look');

/// Minimal audio server the slider only reads the output label from.
class _FakeAudioDevicesRepository implements AudioDevicesRepository {
  @override
  Future<Either<Failure, AudioDevices>> read() async => Right(
    AudioDevices(
      outputName: 'speaker',
      outputLabel: 'Speaker',
      outputs: const [
        AudioOutput(
          name: 'speaker',
          label: 'Speaker',
          volume: 55,
          muted: false,
          isDefault: true,
        ),
      ],
      inputName: 'mic',
      inputLabel: 'Microphone',
      inputs: const [
        AudioInput(
          name: 'mic',
          label: 'Microphone',
          volume: 40,
          muted: false,
          isDefault: true,
        ),
      ],
      inputVolume: 40,
    ),
  );

  @override
  Future<Either<Failure, void>> setDefaultOutput(String name) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setDefaultInput(String name) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setInputVolume(int volume) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setInputMuted(bool muted) async =>
      const Right(null);

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

Future<List<String>> _pumpSlider(
  WidgetTester tester, {
  required List<NowPlayingMedia> players,
  int activeIndex = 0,
}) async {
  final selected = <String>[];

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AudioDevicesBloc>(
        create: (_) =>
            AudioDevicesBloc(repository: _FakeAudioDevicesRepository()),
        child: Scaffold(
          body: NowPlayingSlider(
            players: players,
            activeIndex: activeIndex,
            isBusy: false,
            onSelect: selected.add,
            onTogglePlayPause: () {},
            onSkipNext: () {},
            onSkipPrevious: () {},
          ),
        ),
      ),
    ),
  );

  return selected;
}

void main() {
  testWidgets('a single player is a plain card, with no dots', (tester) async {
    final selected = await _pumpSlider(tester, players: [_spotifyTrack]);

    expect(find.text('Nightcall'), findsOneWidget);
    expect(find.byKey(const ValueKey('now-playing-dot-0')), findsNothing);

    // Nothing to slide to, so a swipe must not select another player.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();

    expect(selected, isEmpty);
    expect(find.text('Nightcall'), findsOneWidget);
  });

  testWidgets('several players page and report the swipe', (tester) async {
    final selected = await _pumpSlider(
      tester,
      players: [_spotifyTrack, _vlcTrack],
    );

    expect(find.byKey(const ValueKey('now-playing-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('now-playing-dot-1')), findsOneWidget);
    expect(find.text('Nightcall'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    // The waveform loops while playing, so settle the page snap explicitly
    // instead of waiting for every animation to stop.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(selected, [_vlc]);
    expect(find.text('Odd Look'), findsOneWidget);
  });

  testWidgets('a dot jumps straight to its player', (tester) async {
    final selected = await _pumpSlider(
      tester,
      players: [_spotifyTrack, _vlcTrack],
    );

    await tester.tap(find.byKey(const ValueKey('now-playing-dot-1')));
    await tester.pump();

    expect(selected, [_vlc]);
  });

  testWidgets('the slider follows a selection made outside it', (tester) async {
    // The bloc can move the selection - a player started playing, or a dot was
    // tapped - and the visible page has to follow.
    await _pumpSlider(tester, players: [_spotifyTrack, _vlcTrack]);
    expect(find.text('Nightcall'), findsOneWidget);

    final selected = await _pumpSlider(
      tester,
      players: [_spotifyTrack, _vlcTrack],
      activeIndex: 1,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Odd Look'), findsOneWidget);
    expect(find.text('Nightcall'), findsNothing);
    // A move the slider made itself is not reported back as a selection, which
    // is what keeps it from fighting the bloc.
    expect(selected, isEmpty);
  });

  testWidgets('no player shows the idle card', (tester) async {
    await _pumpSlider(tester, players: const []);

    expect(find.text('Nothing playing'), findsOneWidget);
    expect(find.byKey(const ValueKey('now-playing-dot-0')), findsNothing);
  });
}
