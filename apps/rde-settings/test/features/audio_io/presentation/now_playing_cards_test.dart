import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_card.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/curvy_progress.dart';

NowPlayingMedia _media({
  String busName = 'org.mpris.MediaPlayer2.spotify',
  String playerName = 'Spotify',
  String? title = 'Nightcall',
  List<String> artists = const ['Kavinsky'],
  String? album = 'OutRun',
  MprisPlaybackStatus status = MprisPlaybackStatus.playing,
  Duration? length = const Duration(minutes: 3, seconds: 34),
  Duration? position = const Duration(seconds: 30),
  bool canGoNext = true,
  bool canGoPrevious = true,
  bool canControl = true,
  bool canPlay = true,
  bool canPause = true,
}) {
  return NowPlayingMedia(
    busName: busName,
    playerName: playerName,
    status: status,
    title: title,
    artists: artists,
    album: album,
    artUrl: null,
    length: length,
    position: position,
    canControl: canControl,
    canPlay: canPlay,
    canPause: canPause,
    canGoNext: canGoNext,
    canGoPrevious: canGoPrevious,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  NowPlayingMedia? media,
  bool isBusy = false,
  String? outputDeviceName,
  VoidCallback? onTogglePlayPause,
  VoidCallback? onSkipNext,
  VoidCallback? onSkipPrevious,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 720,
          child: NowPlayingCard(
            media: media,
            isBusy: isBusy,
            outputDeviceName: outputDeviceName,
            onTogglePlayPause: onTogglePlayPause ?? () {},
            onSkipNext: onSkipNext ?? () {},
            onSkipPrevious: onSkipPrevious ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the track and output device the player reports', (
    tester,
  ) async {
    await _pumpCard(tester, media: _media(), outputDeviceName: 'Speaker');

    expect(find.text('Nightcall'), findsOneWidget);
    expect(find.text('Kavinsky • OutRun'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
  });

  testWidgets('a paused player shows a play button', (tester) async {
    await _pumpCard(tester, media: _media(status: MprisPlaybackStatus.paused));

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
  });

  testWidgets('a player with a position and length draws its progress', (
    tester,
  ) async {
    await _pumpCard(tester, media: _media());

    expect(find.byType(CurvyProgress), findsOneWidget);
  });

  testWidgets('a player with nothing to measure draws no progress', (
    tester,
  ) async {
    await _pumpCard(tester, media: _media(position: null));
    expect(find.byType(CurvyProgress), findsNothing);

    await _pumpCard(tester, media: _media(length: null));
    expect(find.byType(CurvyProgress), findsNothing);
  });

  testWidgets('a player without metadata still names itself', (tester) async {
    await _pumpCard(
      tester,
      media: _media(title: null, artists: const [], album: null),
    );

    expect(find.text('No track loaded'), findsOneWidget);
    expect(find.text('Unknown artist'), findsOneWidget);
  });

  testWidgets('the transport buttons report their taps', (tester) async {
    var toggles = 0;
    var nexts = 0;
    var previouses = 0;

    await _pumpCard(
      tester,
      media: _media(),
      onTogglePlayPause: () => toggles += 1,
      onSkipNext: () => nexts += 1,
      onSkipPrevious: () => previouses += 1,
    );

    await tester.tap(find.byTooltip('Pause'));
    await tester.tap(find.byTooltip('Next track'));
    await tester.tap(find.byTooltip('Previous track'));

    expect(toggles, 1);
    expect(nexts, 1);
    expect(previouses, 1);
  });

  testWidgets('a player with nothing to skip past gets disabled buttons', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      media: _media(canGoNext: false, canGoPrevious: false),
    );

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a player that accepts no calls gets a disabled play button', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      media: _media(canControl: false, canPlay: false, canPause: false),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithIcon(FilledButton, Icons.pause_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a player that can only play still gets a working button', (
    tester,
  ) async {
    // MPRIS pauses through the same call that plays, so `CanPause = false`
    // with `CanPlay = true` is a player that can be toggled, not a broken one.
    var toggles = 0;

    await _pumpCard(
      tester,
      media: _media(canPause: false),
      onTogglePlayPause: () => toggles += 1,
    );

    await tester.tap(find.byTooltip('Pause'));

    expect(toggles, 1);
  });

  testWidgets('a transport action in flight replaces the controls', (
    tester,
  ) async {
    await _pumpCard(tester, media: _media(), isBusy: true);

    expect(find.byType(RdeLoadingIndicator), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    expect(find.byTooltip('Next track'), findsNothing);
  });

  testWidgets('nothing playing explains how to start playback', (tester) async {
    await _pumpCard(tester);

    expect(find.text('Nothing playing'), findsOneWidget);
    expect(
      find.text('Start playback in a media player to control it here'),
      findsOneWidget,
    );
    expect(find.byTooltip('Play'), findsNothing);
  });
}
