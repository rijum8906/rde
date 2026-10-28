import 'package:dbus/dbus.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Decodes one player's MPRIS property dictionary into a [NowPlayingMedia].
///
/// MPRIS is loose about types in practice: `Metadata` is a `a{sv}` whose values
/// are variants, `xesam:artist` is normally an `as` but some players send a
/// plain string, and `mpris:length` is a signed 64-bit microsecond count. The
/// helpers below unwrap variants and tolerate the narrower types instead of
/// casting, so one unusual player cannot break the card for the others.
///
/// Missing properties decode to the sentinel the UI expects: a player that
/// publishes no `Metadata` has no title rather than an empty one, and one that
/// omits `CanGoNext` cannot skip.
class NowPlayingMediaModel {
  const NowPlayingMediaModel();

  /// Builds a player from its MPRIS properties.
  ///
  /// # Parameters
  /// - [busName]: well-known name the player owns.
  /// - [identity]: the player's `Identity`, or `null` when it does not publish
  ///   one; the bus name is then used as the display name.
  /// - [properties]: the reply to `GetAll` on `org.mpris.MediaPlayer2.Player`.
  NowPlayingMedia fromDBus({
    required String busName,
    required String? identity,
    required Map<String, DBusValue> properties,
  }) {
    final metadata = _dict(properties['Metadata']);

    return NowPlayingMedia(
      busName: busName,
      playerName: _playerName(identity, busName),
      status: _status(_string(properties['PlaybackStatus'])),
      title: _string(metadata['xesam:title']),
      artists: _stringList(metadata['xesam:artist']),
      album: _string(metadata['xesam:album']),
      artUrl: _string(metadata['mpris:artUrl']),
      length: _length(metadata['mpris:length']),
      position: _microseconds(properties['Position']),
      // A player that publishes the Player interface accepts calls unless it
      // says otherwise; the queue flags default to the other way around,
      // because a player with nothing to skip between reports `false` and an
      // absent flag must not enable a button that would fail.
      canControl: _bool(properties['CanControl']) ?? true,
      canPlay: _bool(properties['CanPlay']) ?? true,
      canPause: _bool(properties['CanPause']) ?? true,
      canGoNext: _bool(properties['CanGoNext']) ?? false,
      canGoPrevious: _bool(properties['CanGoPrevious']) ?? false,
    );
  }

  /// Display name for a player that publishes no `Identity`.
  ///
  /// The bus name carries the player as its last segment
  /// (`org.mpris.MediaPlayer2.vlc`), so it is capitalized into `Vlc` instead of
  /// showing the whole bus name on the card.
  String _playerName(String? identity, String busName) {
    if (identity != null && identity.isNotEmpty) {
      return identity;
    }

    final segments = busName.split('.');
    final name = segments.isEmpty ? busName : segments.last;
    if (name.isEmpty) {
      return busName;
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  MprisPlaybackStatus _status(String? value) {
    switch (value) {
      case 'Playing':
        return MprisPlaybackStatus.playing;
      case 'Paused':
        return MprisPlaybackStatus.paused;
      default:
        return MprisPlaybackStatus.stopped;
    }
  }

  /// Unwraps the variant a `a{sv}` dictionary stores its values in.
  DBusValue? _unwrap(DBusValue? value) =>
      value is DBusVariant ? value.value : value;

  /// Reads a `a{sv}` entry, tolerating a value that is not a dictionary.
  Map<String, DBusValue> _dict(DBusValue? value) {
    final unwrapped = _unwrap(value);
    if (unwrapped is! DBusDict) {
      return const {};
    }

    final entries = <String, DBusValue>{};
    for (final entry in unwrapped.children.entries) {
      final key = entry.key;
      if (key is DBusString) {
        entries[key.value] = entry.value;
      }
    }
    return entries;
  }

  String? _string(DBusValue? value) {
    final unwrapped = _unwrap(value);
    return unwrapped is DBusString ? unwrapped.value : null;
  }

  /// Reads a string list, accepting a bare string as a one-element list.
  List<String> _stringList(DBusValue? value) {
    final unwrapped = _unwrap(value);
    if (unwrapped is DBusArray) {
      return unwrapped.children
          .map(_string)
          .whereType<String>()
          .where((artist) => artist.isNotEmpty)
          .toList();
    }

    final single = _string(unwrapped);
    return single == null || single.isEmpty ? const [] : [single];
  }

  bool? _bool(DBusValue? value) {
    final unwrapped = _unwrap(value);
    return unwrapped is DBusBoolean ? unwrapped.value : null;
  }

  /// Reads `mpris:length`, reported as a 64-bit signed microsecond count.
  ///
  /// A length of zero is not a track of no duration, it is a player that has
  /// not loaded one, so it reads as unknown and the card hides its progress.
  Duration? _length(DBusValue? value) {
    final length = _microseconds(value);
    if (length == null || length.inMicroseconds <= 0) {
      return null;
    }
    return length;
  }

  /// Reads a microsecond count, as `mpris:length` and `Position` both are.
  ///
  /// Zero is kept: `Position` is zero at the start of every track, which is a
  /// real position the progress bar has to draw.
  Duration? _microseconds(DBusValue? value) {
    final unwrapped = _unwrap(value);
    if (unwrapped is DBusInt64) {
      return Duration(microseconds: unwrapped.value);
    }

    // Some players send the length in a wider or narrower integer type.
    if (unwrapped is DBusUint64) {
      return Duration(microseconds: unwrapped.value);
    }
    if (unwrapped is DBusInt32) {
      return Duration(microseconds: unwrapped.value);
    }
    if (unwrapped is DBusUint32) {
      return Duration(microseconds: unwrapped.value);
    }
    return null;
  }
}
