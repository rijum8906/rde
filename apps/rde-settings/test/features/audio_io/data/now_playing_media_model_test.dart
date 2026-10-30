import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_settings/features/audio_io/data/models/now_playing_media_model.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

const String _spotify = 'org.mpris.MediaPlayer2.spotify';

/// The properties a real player publishes, as
/// `busctl --user introspect org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2`
/// reports them: `Metadata` is a `a{sv}` holding variants, `mpris:length` and
/// `Position` are 64-bit microsecond counts, and `xesam:artist` is an array of
/// strings.
Map<String, DBusValue> _playerReply({
  String status = 'Playing',
  DBusValue? metadata,
  DBusValue? position = const DBusInt64(30000000),
}) {
  return {
    'PlaybackStatus': DBusString(status),
    'Position': position ?? DBusInt64(0),
    'CanControl': DBusBoolean(true),
    'CanPlay': DBusBoolean(true),
    'CanPause': DBusBoolean(true),
    'CanGoNext': DBusBoolean(true),
    'CanGoPrevious': DBusBoolean(true),
    'Metadata': metadata ?? _metadata(),
  };
}

DBusValue _metadata({DBusValue? artist, DBusValue? title, DBusValue? length}) {
  return DBusVariant(
    DBusDict(DBusSignature('s'), DBusSignature('v'), {
      DBusString('mpris:trackid'): DBusVariant(
        DBusObjectPath('/org/mpris/MediaPlayer2/Track/7'),
      ),
      DBusString('mpris:length'): length ?? DBusVariant(DBusInt64(214000000)),
      DBusString('mpris:artUrl'): DBusVariant(
        DBusString('file:///home/user/.cache/cover.png'),
      ),
      DBusString('xesam:title'): title ?? DBusVariant(DBusString('Nightcall')),
      DBusString('xesam:artist'):
          artist ??
          DBusVariant(DBusArray(DBusSignature('s'), [DBusString('Kavinsky')])),
      DBusString('xesam:album'): DBusVariant(DBusString('OutRun')),
    }),
  );
}

NowPlayingMedia _decode(
  Map<String, DBusValue> properties, {
  String busName = _spotify,
  String? identity = 'Spotify',
}) {
  return const NowPlayingMediaModel().fromDBus(
    busName: busName,
    identity: identity,
    properties: properties,
  );
}

void main() {
  test('decodes the types a real MPRIS player reports', () {
    final media = _decode(_playerReply());

    expect(media.busName, _spotify);
    expect(media.playerName, 'Spotify');
    expect(media.status, MprisPlaybackStatus.playing);
    expect(media.title, 'Nightcall');
    expect(media.artists, ['Kavinsky']);
    expect(media.artistLabel, 'Kavinsky');
    expect(media.album, 'OutRun');
    expect(media.artUrl, 'file:///home/user/.cache/cover.png');
    expect(media.length, const Duration(microseconds: 214000000));
    expect(media.position, const Duration(seconds: 30));
    expect(media.lengthLabel, '3:34');
    expect(media.hasProgress, isTrue);
    expect(media.canSkipNext, isTrue);
    expect(media.canSkipPrevious, isTrue);
  });

  test('keeps a zero position, which is the start of a track', () {
    final media = _decode(_playerReply(position: DBusInt64(0)));

    expect(media.position, Duration.zero);
    expect(media.hasProgress, isTrue);
  });

  test('keeps the queue and control flags the player reports', () {
    final media = _decode({
      ..._playerReply(status: 'Paused'),
      'CanGoNext': DBusBoolean(false),
      'CanGoPrevious': DBusBoolean(false),
      'CanControl': DBusBoolean(false),
    });

    expect(media.status, MprisPlaybackStatus.paused);
    expect(media.statusLabel, 'Paused');
    expect(media.canSkipNext, isFalse);
    expect(media.canSkipPrevious, isFalse);
    expect(media.canTogglePlayback, isFalse);
  });

  test('accepts a single artist sent as a bare string', () {
    final media = _decode(
      _playerReply(
        metadata: _metadata(artist: DBusVariant(DBusString('Kavinsky'))),
      ),
    );

    expect(media.artists, ['Kavinsky']);
  });

  test('shows no track when the player publishes no metadata', () {
    final media = _decode({
      'PlaybackStatus': DBusString('Stopped'),
      'CanControl': DBusBoolean(true),
    });

    expect(media.hasTrack, isFalse);
    expect(media.title, isNull);
    expect(media.artists, isEmpty);
    expect(media.artistLabel, 'Unknown artist');
    expect(media.length, isNull);
    expect(media.position, isNull);
    expect(media.hasProgress, isFalse);
    expect(media.status, MprisPlaybackStatus.stopped);
  });

  test('a zero track length is unknown, not an empty track', () {
    final media = _decode(
      _playerReply(metadata: _metadata(length: DBusVariant(DBusInt64(0)))),
    );

    expect(media.length, isNull);
    expect(media.lengthLabel, isNull);
    // The player still reports where it is, but with nothing to measure
    // against there is no progress to draw.
    expect(media.hasProgress, isFalse);
  });

  test('an unknown playback status is treated as stopped', () {
    final media = _decode(_playerReply(status: 'Buffering'));

    expect(media.status, MprisPlaybackStatus.stopped);
  });

  test('falls back to the bus name when the player has no Identity', () {
    final media = _decode(_playerReply(), identity: null);

    expect(media.playerName, 'Spotify');
  });

  test('reads a track length sent as a wider or narrower integer', () {
    expect(
      _decode(
        _playerReply(
          metadata: _metadata(length: DBusVariant(DBusUint64(214000000))),
        ),
      ).lengthLabel,
      '3:34',
    );
    expect(
      _decode(
        _playerReply(
          metadata: _metadata(length: DBusVariant(DBusInt32(214000000))),
        ),
      ).lengthLabel,
      '3:34',
    );
  });
}
