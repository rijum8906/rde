import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/battery_health/data/models/battery_snapshot_model.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';

/// Talks to `org.freedesktop.UPower` over the system bus.
///
/// UPower is the daemon that owns the battery: it publishes one object per
/// device under `/org/freedesktop/UPower/devices`, named after the hardware
/// (`battery_BAT0`), plus a composite `display_device` alias. The page reads
/// the real device object, so every read and mutation goes to the daemon and
/// the page and `upower -d` describe the same state.
class UPowerProxy {
  /// Well-known bus name of the daemon.
  static const String serviceName = 'org.freedesktop.UPower';

  /// Object the daemon exports its own methods on.
  static final DBusObjectPath rootPath = DBusObjectPath(
    '/org/freedesktop/UPower',
  );

  /// Composite battery alias the daemon publishes.
  ///
  /// It is a symlink onto the real device, so it is only used when the device
  /// objects cannot be enumerated.
  static final DBusObjectPath displayDevicePath = DBusObjectPath(
    '/org/freedesktop/UPower/devices/display_device',
  );

  /// `UP_DEVICE_KIND_BATTERY` in `up-types.h`.
  static const int _batteryDeviceType = 2;

  /// Namespace holding every device object, including the real battery behind
  /// the `display_device` alias.
  static final DBusObjectPath devicesPath = DBusObjectPath(
    '/org/freedesktop/UPower/devices',
  );

  /// Interface a device object exposes.
  static const String deviceInterface = 'org.freedesktop.UPower.Device';

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  final DBusClient client = RdeDbus.systemClient;

  UPowerProxy({this._model = const BatterySnapshotModel()});

  final BatterySnapshotModel _model;

  /// Real object path of the battery, cached until a call fails.
  String? _deviceObjectPath;

  /// Reads the battery device the page shows.
  ///
  /// # Errors
  /// Returns an [RdeError] when UPower cannot be reached or its payload cannot
  /// be decoded.
  Future<Either<RdeError, BatterySnapshot>> snapshot() {
    return _read('read the battery state', () async {
      final response = await client.callMethod(
        destination: serviceName,
        path: DBusObjectPath(await _devicePath()),
        interface: propertiesInterface,
        name: 'GetAll',
        values: const [DBusString(deviceInterface)],
        replySignature: DBusSignature('a{sv}'),
      );
      return _model.fromDBus(response.returnValues.first.asStringVariantDict());
    });
  }

  /// Resolves the object path of the battery the page manages.
  ///
  /// UPower names its device objects after the hardware - `battery_BAT0`,
  /// `battery_BAT1` - so the path is looked up instead of assumed: the daemon's
  /// devices are enumerated and the first one whose `Type` is battery is used.
  /// That follows the machine's battery name and picks the right object on a
  /// system with more than one. When the devices cannot be read, the composite
  /// `display_device` alias is used as a fallback.
  Future<String> _devicePath() async {
    final cached = _deviceObjectPath;
    if (cached != null) {
      return cached;
    }

    try {
      final response = await client.callMethod(
        destination: serviceName,
        path: rootPath,
        interface: serviceName,
        name: 'EnumerateDevices',
        replySignature: DBusSignature('ao'),
      );
      for (final path in response.returnValues.first.asObjectPathArray()) {
        if (await _deviceType(path) == _batteryDeviceType) {
          return _deviceObjectPath = path.value;
        }
      }
    } catch (_) {
      // The alias below still gives the page a composite reading.
    }

    return displayDevicePath.value;
  }

  /// Reads the `Type` of one device, which tells a battery from line power.
  Future<int> _deviceType(DBusObjectPath path) async {
    final response = await client.callMethod(
      destination: serviceName,
      path: path,
      interface: propertiesInterface,
      name: 'Get',
      values: const [DBusString(deviceInterface), DBusString('Type')],
    );
    return response.returnValues.first.asVariant().asUint32();
  }

  /// Enables or disables the charge threshold.
  ///
  /// # Errors
  /// Returns an [RdeError] when the device rejects the change, for example
  /// because it has no threshold driver.
  Future<Either<RdeError, void>> enableChargeThreshold(bool enabled) {
    return _write('change the charge threshold', () async {
      await client.callMethod(
        destination: serviceName,
        path: DBusObjectPath(await _devicePath()),
        interface: deviceInterface,
        name: 'EnableChargeThreshold',
        values: [DBusBoolean(enabled)],
      );
    });
  }

  /// Sets the charge end threshold, in percent (typically 60–100).
  ///
  /// # Errors
  /// Returns an [RdeError] when the device rejects the value.
  Future<Either<RdeError, void>> setChargeEndThreshold(int percent) {
    return _write('set the charge end threshold', () async {
      await client.callMethod(
        destination: serviceName,
        path: DBusObjectPath(await _devicePath()),
        interface: propertiesInterface,
        name: 'Set',
        values: [
          const DBusString(deviceInterface),
          const DBusString('ChargeEndThreshold'),
          DBusVariant(DBusUint32(percent)),
        ],
      );
    });
  }

  /// Watches the battery for the signals that change what the page shows.
  ///
  /// UPower reports every battery property through `PropertiesChanged` on the
  /// device object itself, so the whole `/devices` namespace is subscribed
  /// instead of the `display_device` alias, which is a symlink and is not
  /// guaranteed to be the path the signal is sent from. Events carry no
  /// payload: the page reads the authoritative values back from the daemon.
  ///
  /// # Returns
  /// A broadcast stream that emits once per relevant UPower signal.
  ///
  /// # Errors
  /// The stream never reports errors; signals are a best-effort live update and
  /// user actions still refresh the page.
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
            pathNamespace: devicesPath,
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
      // A failed call can mean the battery was swapped, so the resolved path is
      // dropped and looked up again on the next read.
      _deviceObjectPath = null;
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
      _deviceObjectPath = null;
      return Left(RdeError('Could not $action: $error', RdeErrorType.dbus));
    }
  }
}
