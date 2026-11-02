import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';

/// Talks to the RDE brightness service on the session bus.
///
/// `org.rde.Brightness` owns the backlight, so the page never guesses a value:
/// it reads the properties, writes through the service, and listens to the
/// `BrightnessChanged` signal for changes another client made. The service does
/// not emit `PropertiesChanged` for its properties, which is why the custom
/// signal is watched instead.
class BrightnessProxy {
  BrightnessProxy();

  /// Well-known name the brightness service claims on the session bus.
  static const String serviceName = 'org.rde.Brightness';

  /// Interface carrying the brightness properties, methods and signals.
  static const String interface = 'org.rde.Brightness';

  /// Object the service exports its interface on.
  static final DBusObjectPath objectPath = DBusObjectPath(
    '/org/rde/Brightness',
  );

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  final DBusClient client = RdeDbus.sessionClient;

  /// Reads the percentage, raw value, scale and version in one call.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running.
  Future<Either<RdeError, BrightnessLevel>> read() {
    return _read('read the display brightness', () async {
      final response = await client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'GetAll',
        values: const [DBusString(interface)],
        replySignature: DBusSignature('a{sv}'),
      );
      final properties = response.returnValues.first.asStringVariantDict();

      return BrightnessLevel(
        percent: _int(properties, 'BrightnessPercentage') ?? 0,
        raw: _int(properties, 'Brightness') ?? 0,
        max: _int(properties, 'MaxBrightness') ?? 0,
        version: _string(properties, 'Version') ?? 'unknown',
      );
    });
  }

  /// Sets the active display to [percent]; the service clamps it.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> setPercent(int percent) {
    final value = percent.clamp(0, 100).toInt();

    return _write(
      'change the display brightness',
      () => client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: propertiesInterface,
        name: 'Set',
        values: [
          const DBusString(interface),
          const DBusString('BrightnessPercentage'),
          DBusVariant(DBusUint32(value)),
        ],
      ),
    );
  }

  /// Raises the active display by [step] percentage points.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> increase(int step) {
    return _write(
      'raise the display brightness',
      () => client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interface,
        name: 'IncreaseBrightness',
        values: [DBusUint32(step.clamp(0, 100).toInt())],
      ),
    );
  }

  /// Lowers the active display by [step] percentage points.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or rejects the
  /// value.
  Future<Either<RdeError, void>> decrease(int step) {
    return _write(
      'lower the display brightness',
      () => client.callMethod(
        destination: serviceName,
        path: objectPath,
        interface: interface,
        name: 'DecreaseBrightness',
        values: [DBusUint32(step.clamp(0, 100).toInt())],
      ),
    );
  }

  /// Watches the service for brightness changes.
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

    // Step 2: Keep the signal alive for exactly as long as the card listens.
    controller = StreamController<void>.broadcast(
      onListen: () {
        cancelled = false;
        subscriptions.add(
          DBusSignalStream(
            client,
            interface: interface,
            name: 'BrightnessChanged',
            path: objectPath,
            signature: DBusSignature('u'),
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

  /// Reads a string property, or `null` when it is absent.
  String? _string(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    return value is DBusString ? value.value : null;
  }
}
