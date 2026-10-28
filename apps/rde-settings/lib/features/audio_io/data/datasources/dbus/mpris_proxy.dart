import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/audio_io/data/models/now_playing_media_model.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Talks to MPRIS media players over the session bus.
///
/// MPRIS is not a daemon with a fixed object path: every player (`Spotify`,
/// `vlc`, a browser tab) claims its own well-known name
/// `org.mpris.MediaPlayer2.<player>` and exports the same two interfaces on
/// `/org/mpris/MediaPlayer2`. The page therefore lists the names on the bus and
/// reads each player's properties from there, so the card describes the players
/// that are actually running instead of one hard-coded service.
///
/// Reading a player is best-effort by design: a player can quit between the
/// name list and the property read, and one dying player must not blank the
/// card for the others.
class MprisProxy {
  MprisProxy({this._model = const NowPlayingMediaModel()});

  /// Prefix every MPRIS player uses for its well-known bus name.
  static const String servicePrefix = 'org.mpris.MediaPlayer2';

  /// Object every player exports its interfaces on.
  static final DBusObjectPath objectPath = DBusObjectPath(
    '/org/mpris/MediaPlayer2',
  );

  /// Interface carrying `Identity` and the player's application metadata.
  static const String rootInterface = 'org.mpris.MediaPlayer2';

  /// Interface carrying `Metadata`, `PlaybackStatus`, and the transport
  /// methods.
  static const String playerInterface = 'org.mpris.MediaPlayer2.Player';

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  /// Owner of the bus itself: the name list and `NameOwnerChanged` come from
  /// here.
  static const String busService = 'org.freedesktop.DBus';

  /// Object the bus daemon publishes its own methods on.
  static final DBusObjectPath busPath = DBusObjectPath('/org/freedesktop/DBus');

  /// Interface the bus daemon exposes.
  static const String busInterface = 'org.freedesktop.DBus';

  final DBusClient client = RdeDbus.sessionClient;

  final NowPlayingMediaModel _model;

  /// Lists the players that are running, in a stable order.
  ///
  /// # Returns
  /// One [NowPlayingMedia] per player that answered, sorted by bus name so the
  /// card's order does not shuffle between reads.
  ///
  /// # Errors
  /// Returns an [RdeError] only when the bus itself cannot be reached; a player
  /// that fails to answer is skipped.
  Future<Either<RdeError, List<NowPlayingMedia>>> players() {
    return _read('read the media players', () async {
      final names = await client.listNames();

      // Step 1: A player that quits mid-read is dropped, not fatal.
      final players = <NowPlayingMedia>[];
      for (final busName in _playerNames(names)) {
        final player = await _player(busName);
        if (player != null) {
          players.add(player);
        }
      }
      return players;
    });
  }

  /// Flips the player between playing and paused.
  ///
  /// # Errors
  /// Returns an [RdeError] when the player is gone or refuses the call, for
  /// example because it does not implement `CanPause`.
  Future<Either<RdeError, void>> togglePlayPause(NowPlayingMedia media) {
    return _write('toggle playback', () => _call(media, 'PlayPause'));
  }

  /// Skips to the next track in the player's queue.
  ///
  /// # Errors
  /// Returns an [RdeError] when the player is gone or refuses the call.
  Future<Either<RdeError, void>> skipToNext(NowPlayingMedia media) {
    return _write('skip to the next track', () => _call(media, 'Next'));
  }

  /// Skips back to the previous track in the player's queue.
  ///
  /// # Errors
  /// Returns an [RdeError] when the player is gone or refuses the call.
  Future<Either<RdeError, void>> skipToPrevious(NowPlayingMedia media) {
    return _write('skip to the previous track', () => _call(media, 'Previous'));
  }

  /// Watches the bus for changes the card has to show.
  ///
  /// Two things make the card stale: the track or playback state of a player
  /// changing, and players starting or quitting. The first arrives as
  /// `PropertiesChanged` on the shared MPRIS object path - the `Metadata`
  /// dictionary is rewritten for every new track, which is the "music changed"
  /// signal - and the second as `NameOwnerChanged` on the bus daemon.
  ///
  /// # Returns
  /// A broadcast stream that emits once per relevant signal, with no payload:
  /// the card reads the authoritative properties back from the player.
  ///
  /// # Errors
  /// The stream never reports errors; signals are a best-effort live update and
  /// the transport buttons still refresh the card.
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    var subscriptions = <StreamSubscription<DBusSignal>>[];
    var cancelled = false;

    // Step 1: Publish one event to every listener, tolerating late arrivals.
    void emit() {
      if (!cancelled && controller.hasListener) {
        controller.add(null);
      }
    }

    // Step 2: Keep both watches alive for exactly as long as the card listens.
    controller = StreamController<void>.broadcast(
      onListen: () {
        cancelled = false;

        subscriptions.add(
          DBusSignalStream(
            client,
            interface: propertiesInterface,
            name: 'PropertiesChanged',
            path: objectPath,
            signature: DBusSignature('sa{sv}as'),
          ).listen((_) => emit(), onError: (Object _) {}),
        );

        // A player can only be reached while its name is on the bus, so the
        // appearance and disappearance of a player name is what adds or drops
        // a card. Other names on the bus - the session manager, the notification
        // daemon - are ignored.
        subscriptions.add(
          DBusSignalStream(
            client,
            interface: busInterface,
            name: 'NameOwnerChanged',
            path: busPath,
          ).listen((signal) {
            if (_isPlayerName(signal)) {
              emit();
            }
          }, onError: (Object _) {}),
        );
      },
      onCancel: () async {
        cancelled = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions = [];
      },
    );
    return controller.stream;
  }

  /// Names of the players on the bus, sorted for a stable card order.
  ///
  /// A player may own queued names such as `org.mpris.MediaPlayer2.vlc.instance`
  /// and the bus itself is named `org.mpris.MediaPlayer2`; the names below the
  /// prefix are the playable ones.
  List<String> _playerNames(List<String> names) {
    return names.where((name) => name.startsWith('$servicePrefix.')).toList()
      ..sort();
  }

  /// Whether a `NameOwnerChanged` payload names an MPRIS player.
  bool _isPlayerName(DBusSignal signal) {
    if (signal.values.isEmpty) {
      return false;
    }
    final name = signal.values.first;
    return name is DBusString && name.value.startsWith('$servicePrefix.');
  }

  /// Reads one player's properties, or `null` when it is no longer there.
  Future<NowPlayingMedia?> _player(String busName) async {
    try {
      final properties = await client.callMethod(
        destination: busName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'GetAll',
        values: const [DBusString(playerInterface)],
        replySignature: DBusSignature('a{sv}'),
      );

      return _model.fromDBus(
        busName: busName,
        identity: await _identity(busName),
        properties: properties.returnValues.first.asStringVariantDict(),
      );
    } catch (_) {
      // The player quit, or does not implement the Player interface at all.
      return null;
    }
  }

  /// Reads the player's `Identity`, the name a user recognizes.
  ///
  /// The property is optional, so a player that omits it falls back to its bus
  /// name rather than disappearing from the list.
  Future<String?> _identity(String busName) async {
    try {
      final response = await client.callMethod(
        destination: busName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Get',
        values: const [DBusString(rootInterface), DBusString('Identity')],
      );
      return response.returnValues.first.asVariant().asString();
    } catch (_) {
      return null;
    }
  }

  /// Calls one transport method on the player [media] came from.
  Future<void> _call(NowPlayingMedia media, String method) {
    return client.callMethod(
      destination: media.busName,
      path: objectPath,
      interface: playerInterface,
      name: method,
    );
  }

  /// Runs a read-only operation and maps failures onto [RdeError].
  Future<Either<RdeError, T>> _read<T>(
    String action,
    Future<T> Function() body,
  ) async {
    try {
      return Right(await body());
    } catch (error) {
      return Left(RdeError('Could not $action: $error', RdeErrorType.dbus));
    }
  }

  /// Runs a mutating operation and maps failures onto [RdeError].
  Future<Either<RdeError, void>> _write(
    String action,
    Future<void> Function() body,
  ) async {
    try {
      await body();
      return const Right(null);
    } catch (error) {
      return Left(RdeError('Could not $action: $error', RdeErrorType.dbus));
    }
  }
}
