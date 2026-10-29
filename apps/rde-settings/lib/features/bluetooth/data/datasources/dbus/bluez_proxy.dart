import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';

/// Talks to the BlueZ daemon over the system bus.
///
/// BlueZ is the Bluetooth stack of the desktop: `bluetoothd` owns the adapter
/// and publishes every device it knows on `org.bluez`. This proxy reads that
/// object tree through `org.freedesktop.DBus.ObjectManager` and drives it
/// through the `org.bluez.Adapter1` and `org.bluez.Device1` interfaces, so the
/// page and `bluetoothctl` always describe the same state.
class BluezProxy {
  /// Well-known bus name of the daemon.
  static const String serviceName = 'org.bluez';

  /// Object path that exports the object manager.
  static final DBusObjectPath rootPath = DBusObjectPath('/');

  /// Object path the daemon owns.
  static final DBusObjectPath bluezPath = DBusObjectPath('/org/bluez');

  /// Interface the daemon exports on [rootPath].
  static const String objectManagerInterface =
      'org.freedesktop.DBus.ObjectManager';

  /// Interface every adapter object exposes.
  static const String adapterInterface = 'org.bluez.Adapter1';

  /// Interface every device object exposes.
  static const String deviceInterface = 'org.bluez.Device1';

  /// Interface a device adds when it reports its battery level.
  static const String batteryInterface = 'org.bluez.Battery1';

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  final DBusClient client = RdeDbus.systemClient;

  BluezProxy();

  /// Reads the adapter and every device BlueZ knows about.
  ///
  /// # Returns
  /// A snapshot holding the first adapter and its devices, connected first and
  /// strongest signal first within the rest. The adapter is `null` when the
  /// machine has no Bluetooth hardware.
  ///
  /// # Errors
  /// Returns an [RdeError] when the daemon cannot be reached.
  Future<Either<RdeError, BluetoothSnapshot>> snapshot() {
    return _read('read the Bluetooth state', () async {
      final objects = await _managedObjects();

      BluetoothAdapter? adapter;
      final devices = <BluetoothDevice>[];
      for (final entry in objects.entries) {
        // Step 1: The first adapter is the one the page manages; a machine
        // with several controllers still gets a usable page.
        final adapterProperties = entry.value[adapterInterface];
        if (adapterProperties != null) {
          adapter ??= _adapter(entry.key, adapterProperties);
          continue;
        }

        // Step 2: Everything else that exposes a device interface is a peer.
        final deviceProperties = entry.value[deviceInterface];
        if (deviceProperties == null) {
          continue;
        }
        devices.add(
          _device(entry.key, deviceProperties, entry.value[batteryInterface]),
        );
      }

      devices.sort(_byRelevance);
      return BluetoothSnapshot(adapter: adapter, devices: devices);
    });
  }

  /// Turns the radio on or off.
  ///
  /// # Errors
  /// Returns an [RdeError] when there is no adapter or the daemon rejects the
  /// change, for example when the radio is blocked by rfkill.
  Future<Either<RdeError, void>> setPowered(bool enabled) {
    return _write(
      enabled ? 'turn Bluetooth on' : 'turn Bluetooth off',
      () async {
        final adapterPath = await _requireAdapterPath();
        await _setProperty(
          DBusObjectPath(adapterPath),
          adapterInterface,
          'Powered',
          DBusBoolean(enabled),
        );
      },
    );
  }

  /// Makes the controller discoverable to other devices, or hides it again.
  ///
  /// # Errors
  /// Returns an [RdeError] when there is no adapter or the daemon rejects the
  /// change.
  Future<Either<RdeError, void>> setDiscoverable(bool discoverable) {
    return _write('change the discoverable state', () async {
      final adapterPath = await _requireAdapterPath();
      await _setProperty(
        DBusObjectPath(adapterPath),
        adapterInterface,
        'Discoverable',
        DBusBoolean(discoverable),
      );
    });
  }

  /// Starts scanning for devices.
  ///
  /// # Errors
  /// Returns an [RdeError] when there is no adapter or the scan cannot start.
  /// A scan that is already running is not an error: it is the state the
  /// caller asked for, and BlueZ reports it as `InProgress`.
  Future<Either<RdeError, void>> startDiscovery() {
    return _write('start scanning for devices', () async {
      final adapterPath = await _requireAdapterPath();
      try {
        await _call(
          DBusObjectPath(adapterPath),
          adapterInterface,
          'StartDiscovery',
        );
      } catch (error) {
        if (_isBenignDiscoveryError(error)) {
          return;
        }
        rethrow;
      }
    });
  }

  /// Stops scanning for devices.
  ///
  /// # Errors
  /// Returns an [RdeError] when there is no adapter or the scan cannot stop.
  Future<Either<RdeError, void>> stopDiscovery() {
    return _write('stop scanning for devices', () async {
      final adapterPath = await _requireAdapterPath();
      try {
        await _call(
          DBusObjectPath(adapterPath),
          adapterInterface,
          'StopDiscovery',
        );
      } catch (error) {
        // Stopping a scan that already stopped is not a failure: the adapter
        // ends up in the state the caller asked for either way.
        if (_isBenignDiscoveryError(error)) {
          return;
        }
        rethrow;
      }
    });
  }

  /// Pairs with the device at [address].
  ///
  /// Pairing needs a pairing agent. The daemon registers a default agent, so a
  /// device that only asks for confirmation pairs without the page registering
  /// one; a device that demands a passkey fails with the daemon's error.
  ///
  /// # Errors
  /// Returns an [RdeError] when no device matches [address] or pairing fails.
  Future<Either<RdeError, void>> pair(String address) {
    return _write('pair with $address', () async {
      final devicePath = await _requireDevicePath(address);
      await _call(DBusObjectPath(devicePath), deviceInterface, 'Pair');
    });
  }

  /// Connects to the device at [address].
  ///
  /// # Errors
  /// Returns an [RdeError] when no device matches [address] or the connection
  /// is refused, for example when the device is not paired.
  Future<Either<RdeError, void>> connect(String address) {
    return _write('connect to $address', () async {
      final devicePath = await _requireDevicePath(address);
      await _call(DBusObjectPath(devicePath), deviceInterface, 'Connect');
    });
  }

  /// Disconnects the device at [address].
  ///
  /// # Errors
  /// Returns an [RdeError] when no device matches [address] or it cannot be
  /// disconnected.
  Future<Either<RdeError, void>> disconnect(String address) {
    return _write('disconnect $address', () async {
      final devicePath = await _requireDevicePath(address);
      await _call(DBusObjectPath(devicePath), deviceInterface, 'Disconnect');
    });
  }

  /// Forgets the device at [address] and its pairing.
  ///
  /// # Errors
  /// Returns an [RdeError] when no device matches [address] or the adapter
  /// rejects the removal.
  Future<Either<RdeError, void>> forget(String address) {
    return _write('forget $address', () async {
      final devicePath = await _requireDevicePath(address);
      final adapterPath = await _requireAdapterPath();
      await _call(
        DBusObjectPath(adapterPath),
        adapterInterface,
        'RemoveDevice',
        [DBusObjectPath(devicePath)],
      );
    });
  }

  /// Marks the device at [address] as trusted, or removes that trust.
  ///
  /// A trusted device may connect without pairing confirmation.
  ///
  /// # Errors
  /// Returns an [RdeError] when no device matches [address] or the change is
  /// rejected.
  Future<Either<RdeError, void>> setTrusted(String address, bool trusted) {
    return _write('change the trust state of $address', () async {
      final devicePath = await _requireDevicePath(address);
      await _setProperty(
        DBusObjectPath(devicePath),
        deviceInterface,
        'Trusted',
        DBusBoolean(trusted),
      );
    });
  }

  /// Watches BlueZ for the signals that change what the page shows.
  ///
  /// One subscription covers every object under `/org/bluez`, because BlueZ
  /// reports device and adapter properties through the same
  /// `PropertiesChanged` signal, and the object manager reports devices that
  /// appear and disappear. Events carry no payload: the page reads the object
  /// tree back, which is authoritative and cheap enough to re-read.
  ///
  /// # Returns
  /// A broadcast stream that emits once per relevant BlueZ signal.
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

    // Step 2: Subscribe to one signal of the daemon.
    StreamSubscription<DBusSignal> subscribe(
      String interface,
      String name, {
      DBusSignature? signature,
      DBusObjectPath? path,
      DBusObjectPath? pathNamespace,
    }) {
      return DBusSignalStream(
        client,
        sender: serviceName,
        interface: interface,
        name: name,
        path: path,
        pathNamespace: pathNamespace,
        signature: signature,
      ).listen((_) => emit(), onError: (Object _) {});
    }

    // Step 3: Keep the watches alive for exactly as long as the page listens.
    controller = StreamController<void>.broadcast(
      onListen: () {
        // Step 3a: Properties of every adapter and device in the tree.
        subscriptions.add(
          subscribe(
            propertiesInterface,
            'PropertiesChanged',
            signature: DBusSignature('sa{sv}as'),
            pathNamespace: bluezPath,
          ),
        );

        // Step 3b: Objects entering and leaving the tree, which is how a
        // discovered device shows up and a forgotten one disappears.
        subscriptions.add(
          subscribe(
            objectManagerInterface,
            'InterfacesAdded',
            signature: DBusSignature('oa{sa{sv}}'),
            path: rootPath,
          ),
        );
        subscriptions.add(
          subscribe(
            objectManagerInterface,
            'InterfacesRemoved',
            signature: DBusSignature('oas'),
            path: rootPath,
          ),
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

  /// Reads every object the daemon manages.
  ///
  /// # Returns
  /// A map from object path to its interfaces and their properties, as
  /// returned by `org.freedesktop.DBus.ObjectManager.GetManagedObjects`.
  Future<Map<String, Map<String, Map<String, DBusValue>>>>
  _managedObjects() async {
    final response = await _call(
      rootPath,
      objectManagerInterface,
      'GetManagedObjects',
    );
    final objects = response.returnValues.first;
    if (objects is! DBusDict) {
      throw const _BluezException(
        'the managed object reply has an unknown shape',
      );
    }

    final result = <String, Map<String, Map<String, DBusValue>>>{};
    for (final object in objects.children.entries) {
      final interfaces = object.value;
      if (interfaces is! DBusDict) {
        continue;
      }

      final byInterface = <String, Map<String, DBusValue>>{};
      for (final interface in interfaces.children.entries) {
        final properties = interface.value;
        if (properties is! DBusDict) {
          continue;
        }
        byInterface[interface.key.asString()] = properties.mapStringVariant();
      }
      result[object.key.asObjectPath().value] = byInterface;
    }
    return result;
  }

  /// Builds the adapter entity for [path].
  BluetoothAdapter _adapter(String path, Map<String, DBusValue> properties) {
    return BluetoothAdapter(
      path: path,
      address: _string(properties, 'Address') ?? '',
      name:
          _string(properties, 'Alias') ??
          _string(properties, 'Name') ??
          _lastPathSegment(path),
      powered: _bool(properties, 'Powered') ?? false,
      discoverable: _bool(properties, 'Discoverable') ?? false,
      discovering: _bool(properties, 'Discovering') ?? false,
    );
  }

  /// Builds the device entity for [path], including its battery when present.
  BluetoothDevice _device(
    String path,
    Map<String, DBusValue> properties,
    Map<String, DBusValue>? batteryProperties,
  ) {
    return BluetoothDevice(
      path: path,
      address: _string(properties, 'Address') ?? '',
      name:
          _string(properties, 'Alias') ??
          _string(properties, 'Name') ??
          _string(properties, 'Address') ??
          _lastPathSegment(path),
      paired: _bool(properties, 'Paired') ?? false,
      trusted: _bool(properties, 'Trusted') ?? false,
      connected: _bool(properties, 'Connected') ?? false,
      servicesResolved: _bool(properties, 'ServicesResolved') ?? false,
      icon: _string(properties, 'Icon'),
      rssi: _int(properties, 'RSSI'),
      batteryPercentage: batteryProperties == null
          ? null
          : _int(batteryProperties, 'Percentage'),
    );
  }

  /// Orders devices the way the page lists them.
  int _byRelevance(BluetoothDevice left, BluetoothDevice right) {
    // Step 1: A connected device is what the user came for.
    if (left.connected != right.connected) {
      return left.connected ? -1 : 1;
    }

    // Step 2: Then the devices that can connect without pairing again.
    if (left.paired != right.paired) {
      return left.paired ? -1 : 1;
    }

    // Step 3: Then the strongest signal, with unknown strength last.
    final leftRssi = left.rssi ?? -1000;
    final rightRssi = right.rssi ?? -1000;
    if (leftRssi != rightRssi) {
      return rightRssi.compareTo(leftRssi);
    }

    // Step 4: Finally by name, so the order is stable between reads.
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  /// Returns the path of the adapter the page manages.
  Future<String> _requireAdapterPath() async {
    final objects = await _managedObjects();
    for (final entry in objects.entries) {
      if (entry.value.containsKey(adapterInterface)) {
        return entry.key;
      }
    }
    throw const _BluezException('no Bluetooth adapter was found');
  }

  /// Returns the path of the device whose address is [address].
  Future<String> _requireDevicePath(String address) async {
    final objects = await _managedObjects();
    for (final entry in objects.entries) {
      final properties = entry.value[deviceInterface];
      if (properties != null && _string(properties, 'Address') == address) {
        return entry.key;
      }
    }
    throw _BluezException('no device with the address "$address" was found');
  }

  /// Writes one property on [path].
  Future<void> _setProperty(
    DBusObjectPath path,
    String interface,
    String name,
    DBusValue value,
  ) async {
    await _call(path, propertiesInterface, 'Set', [
      DBusString(interface),
      DBusString(name),
      DBusVariant(value),
    ]);
  }

  /// Invokes one BlueZ method.
  Future<DBusMethodResponse> _call(
    DBusObjectPath path,
    String interface,
    String name, [
    List<DBusValue> values = const [],
  ]) {
    return client.callMethod(
      destination: serviceName,
      path: path,
      interface: interface,
      name: name,
      values: values,
    );
  }

  /// Reports whether [error] is a discovery error the caller can ignore.
  ///
  /// BlueZ answers a repeated `StartDiscovery` with
  /// `org.bluez.Error.InProgress`, and a `StopDiscovery` on an idle adapter
  /// with `org.bluez.Error.Failed`.
  bool _isBenignDiscoveryError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('inprogress') ||
        message.contains('in progress') ||
        message.contains('not discovering');
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

  /// Reads a string property, or `null` when it is absent.
  String? _string(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    return value is DBusString ? value.value : null;
  }

  /// Reads a boolean property, or `null` when it is absent.
  bool? _bool(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    return value is DBusBoolean ? value.value : null;
  }

  /// Reads an integer property, or `null` when it is absent.
  int? _int(Map<String, DBusValue> properties, String name) {
    final value = properties[name];
    if (value is DBusByte) {
      return value.value;
    }
    if (value is DBusInt16) {
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

  /// Returns the last segment of an object path.
  String _lastPathSegment(String path) {
    final segments = path.split('/');
    return segments.isEmpty ? path : segments.last;
  }
}

/// Local exception used to abort a BlueZ operation with context.
class _BluezException implements Exception {
  const _BluezException(this.message);

  final String message;

  @override
  String toString() => message;
}
