import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';

/// Talks to `org.freedesktop.UPower.PowerProfiles`.
///
/// power-profiles-daemon owns the system power profile: the desktop, the
/// battery page, and `powerprofilesctl` all read and write the one
/// `ActiveProfile` property, so the page never guesses what is active.
class PowerProfilesProxy {
  /// Well-known bus name of the daemon.
  static const String serviceName = 'org.freedesktop.UPower.PowerProfiles';

  /// Object the daemon publishes.
  static final DBusObjectPath objectPath = DBusObjectPath(
    '/org/freedesktop/UPower/PowerProfiles',
  );

  /// Interface the object exposes.
  static const String interface = 'org.freedesktop.UPower.PowerProfiles';

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  /// Property holding the active profile name.
  static const String activeProfileProperty = 'ActiveProfile';

  final DBusClient client = RdeDbus.systemClient;

  /// Reads the profile the daemon reports as active.
  ///
  /// # Errors
  /// Returns an [RdeError] when power-profiles-daemon is not running.
  Future<Either<RdeError, String>> activeProfile() {
    return _read('read the power profile', () async {
      final response = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Get',
        values: const [
          DBusString(interface),
          DBusString(activeProfileProperty),
        ],
      );
      return response.returnValues.first.asVariant().asString();
    });
  }

  /// Activates [profile]: `performance`, `balanced`, or `power-saver`.
  ///
  /// # Errors
  /// Returns an [RdeError] when the daemon rejects the profile.
  Future<Either<RdeError, void>> setActiveProfile(String profile) {
    return _write('set the power profile', () async {
      await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Set',
        values: [
          const DBusString(interface),
          const DBusString(activeProfileProperty),
          DBusVariant(DBusString(profile)),
        ],
      );
    });
  }

  /// Watches the daemon for profile changes made by any client.
  ///
  /// A profile switched from the desktop shell or from `powerprofilesctl` has
  /// to reach the page without a reload, so the object's `PropertiesChanged`
  /// signal is subscribed. Events carry no payload: the page reads the
  /// authoritative profile back from the daemon.
  ///
  /// # Returns
  /// A broadcast stream that emits once per relevant signal.
  ///
  /// # Errors
  /// The stream never reports errors; signals are a best-effort live update.
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

    // Step 2: Keep the watch alive for exactly as long as the page listens.
    controller = StreamController<void>.broadcast(
      onListen: () {
        cancelled = false;
        subscriptions.add(
          DBusSignalStream(
            client,
            sender: serviceName,
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
