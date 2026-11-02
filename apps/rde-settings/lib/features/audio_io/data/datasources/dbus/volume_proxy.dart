import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';

/// Talks to the RDE volume service on the session bus.
///
/// `org.rde.Volume` owns the ALSA mixer, so the page never guesses a value:
/// it reads the properties, writes them through `org.freedesktop.DBus.Properties`,
/// and listens to `PropertiesChanged` for updates another client made.
class VolumeProxy {
  VolumeProxy();

  /// Well-known name the volume service claims on the session bus.
  static const String serviceName = 'org.rde.Volume';

  /// Interface carrying the volume properties, methods and signals.
  static const String interface = 'org.rde.Volume';

  /// Object the service exports its interface on.
  static final DBusObjectPath objectPath = DBusObjectPath('/org/rde/Volume');

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  final DBusClient client = RdeDbus.sessionClient;

  /// Reads the volume, mute state, step and limits in one call.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running.
  Future<Either<RdeError, MasterVolume>> read() {
    return _read('read the master volume', () async {
      final response = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'GetAll',
        values: const [DBusString(interface)],
        replySignature: DBusSignature('a{sv}'),
      );
      final properties = response.returnValues.first.asStringVariantDict();

      return MasterVolume(
        volume: _int(properties, 'Volume') ?? 0,
        muted: _bool(properties, 'Muted') ?? false,
        // The service publishes no limit constants: 0-100 is the contract, and
        // the default adjustment step only exists for the step methods.
        step: 5,
        minVolume: 0,
        maxVolume: 100,
        microphoneVolume: await _readMicrophoneVolume(),
      );
    });
  }

  /// Reads the microphone capture level, or `null` when the service has none.
  ///
  /// This is a separate `Get` instead of part of the `GetAll` above: the
  /// service answers that property with an error on machines without a capture
  /// control, and that error must not blank the master volume card.
  Future<int?> _readMicrophoneVolume() async {
    try {
      final response = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Get',
        values: const [DBusString(interface), DBusString('MicrophoneVolume')],
        replySignature: DBusSignature('v'),
      );
      final value = response.returnValues.first.asVariant();
      if (value is DBusByte) {
        return value.value;
      }
      if (value is DBusInt32) {
        return value.value;
      }
      if (value is DBusUint32) {
        return value.value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sets the master volume to [volume] percent; the service clamps it.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> setVolume(int volume) {
    return _writeProperty(
      'change the master volume',
      'Volume',
      DBusByte(volume),
    );
  }

  /// Sets the microphone capture volume to [volume] percent.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running, the device has no
  /// capture control, or the write is rejected.
  Future<Either<RdeError, void>> setMicrophoneVolume(int volume) {
    return _writeProperty(
      'change the microphone volume',
      'MicrophoneVolume',
      DBusByte(volume),
    );
  }

  /// Mutes or unmutes playback.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> setMuted(bool muted) {
    return _writeProperty('change the mute state', 'Muted', DBusBoolean(muted));
  }

  /// Watches the service for volume and mute changes.
  ///
  /// # Returns
  /// A broadcast stream that emits once per signal, with no payload: the card
  /// reads the authoritative properties back from the service.
  ///
  /// # Errors
  /// The stream never reports errors; a missing service shows up as a failed
  /// read instead.
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

    // Step 2: Keep the property signal alive for exactly as long as the card
    // listens. Every setter and step method ends up here through
    // `PropertiesChanged`.
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

  /// Writes a single D-Bus property through the standard property interface.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> _writeProperty(
    String action,
    String name,
    DBusValue value,
  ) {
    return _write(
      action,
      () => client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Set',
        values: [
          const DBusString(interface),
          DBusString(name),
          DBusVariant(value),
        ],
      ),
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

  /// Reads an integer property, or `null` when it is absent.
  int? _int(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    if (value is DBusByte) {
      return value.value;
    }
    if (value is DBusInt32) {
      return value.value;
    }
    if (value is DBusUint32) {
      return value.value;
    }
    return null;
  }

  /// Reads a boolean property, or `null` when it is absent.
  bool? _bool(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    return value is DBusBoolean ? value.value : null;
  }
}
