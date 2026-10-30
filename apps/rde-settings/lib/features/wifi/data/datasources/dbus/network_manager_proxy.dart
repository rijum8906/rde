import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

/// Talks to the system NetworkManager daemon.
///
/// The settings page is a NetworkManager client, not a client of
/// `org.rde.wifi`: every read and mutation goes to
/// `org.freedesktop.NetworkManager` so the desktop and the service observe the
/// same connection state.
class NetworkManagerProxy {
  /// Well-known bus name of the daemon.
  static const String serviceName = 'org.freedesktop.NetworkManager';

  /// Root object of the daemon.
  static final DBusObjectPath nmObjectPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager',
  );

  /// Object of the connection settings registry.
  static final DBusObjectPath settingsPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager/Settings',
  );

  /// Interface the root object exposes.
  static const String nmInterface = 'org.freedesktop.NetworkManager';

  /// Interface every device object exposes.
  static const String deviceInterface = 'org.freedesktop.NetworkManager.Device';

  /// Interface Wi-Fi device objects add.
  static const String wirelessInterface =
      'org.freedesktop.NetworkManager.Device.Wireless';

  /// Interface access point objects expose.
  static const String accessPointInterface =
      'org.freedesktop.NetworkManager.AccessPoint';

  /// Interface the settings registry exposes.
  static const String settingsInterface =
      'org.freedesktop.NetworkManager.Settings';

  /// Interface one stored connection exposes.
  static const String connectionInterface =
      'org.freedesktop.NetworkManager.Settings.Connection';

  /// Interface the D-Bus property mechanism uses.
  static const String propertiesInterface = 'org.freedesktop.DBus.Properties';

  /// `NM_802_11_AP_FLAGS_PRIVACY`.
  static const int _apFlagPrivacy = 0x1;

  /// `NM_802_11_AP_SEC_KEY_MGMT_PSK`.
  static const int _apSecPsk = 0x100;

  /// `NM_802_11_AP_SEC_KEY_MGMT_802_1X`.
  static const int _apSec8021x = 0x200;

  /// `NM_802_11_AP_SEC_KEY_MGMT_SAE`.
  static const int _apSecSae = 0x400;

  /// `NM_802_11_AP_SEC_KEY_MGMT_OWE`.
  static const int _apSecOwe = 0x800;

  final DBusClient client = RdeDbus.systemClient;

  NetworkManagerProxy();

  /// Returns every network device path NetworkManager manages.
  ///
  /// # Returns
  /// Object paths such as `/org/freedesktop/NetworkManager/Devices/3`.
  ///
  /// # Errors
  /// Returns an [RdeError] when the daemon cannot be reached.
  Future<Either<RdeError, List<String>>> devices() {
    return _read('list network devices', () async {
      final response = await _call(nmObjectPath, nmInterface, 'GetDevices');
      return response.returnValues.first
          .asObjectPathArray()
          .map((path) => path.value)
          .toList();
    });
  }

  /// Reports whether the Wi-Fi radio is enabled.
  ///
  /// # Errors
  /// Returns an [RdeError] when NetworkManager cannot be reached.
  Future<Either<RdeError, bool>> wirelessEnabled() {
    return _read('read the Wi-Fi radio state', () async {
      final value = await _property(
        nmObjectPath,
        nmInterface,
        'WirelessEnabled',
      );
      return value.asBoolean();
    });
  }

  /// Turns the Wi-Fi radio on or off.
  ///
  /// # Errors
  /// Returns an [RdeError] when NetworkManager rejects the change, for example
  /// when the radio is blocked by rfkill.
  Future<Either<RdeError, void>> setWirelessEnabled(bool enabled) {
    return _write('set the Wi-Fi radio', () async {
      await _setProperty(
        nmObjectPath,
        nmInterface,
        'WirelessEnabled',
        DBusBoolean(enabled),
      );
    });
  }

  /// Watches the signals that change what the Wi-Fi page shows.
  ///
  /// The page is a live view rather than a snapshot: a radio toggled from a
  /// terminal, a connection activated by another client, an access point that
  /// appears or disappears, and a profile that is added or deleted all have to
  /// reach it without the user pressing Rescan. The daemon sends no single
  /// "the Wi-Fi state changed" signal, so every watch below is subscribed and
  /// their events are collapsed into one stream. Events carry no payload,
  /// because the page reads the authoritative state back from NetworkManager.
  ///
  /// # Returns
  /// A broadcast stream that emits once per relevant NetworkManager signal.
  ///
  /// # Errors
  /// The stream never reports errors: signals are a best-effort live update,
  /// and a filter the daemon rejects is ignored so the page keeps working.
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    var rootSubscriptions = <StreamSubscription<DBusSignal>>[];
    var deviceSubscriptions = <StreamSubscription<DBusSignal>>[];
    var cancelled = false;

    // Step 1: Publish one event to every listener, tolerating late arrivals.
    void emit() {
      if (!cancelled && controller.hasListener) {
        controller.add(null);
      }
    }

    // Step 2: Subscribe to one signal of one object. A rejected signal filter
    // is swallowed so a single unsupported signal cannot break the live view.
    StreamSubscription<DBusSignal> subscribe(
      DBusObjectPath path,
      String signalInterface,
      String name, {
      DBusSignature? signature,
      void Function()? onSignal,
    }) {
      final object = DBusRemoteObject(client, name: serviceName, path: path);
      return DBusRemoteObjectSignalStream(
        object: object,
        interface: signalInterface,
        name: name,
        signature: signature,
      ).listen(
        (_) {
          onSignal?.call();
          emit();
        },
        onError: (Object _) {
          // Live updates are best effort; user actions still refresh the page.
        },
      );
    }

    // Step 3: Wi-Fi devices come and go, so their subscriptions are rebuilt
    // whenever the daemon reports a device was added or removed.
    Future<void> subscribeDevices() async {
      for (final subscription in deviceSubscriptions) {
        await subscription.cancel();
      }
      deviceSubscriptions = [];
      if (cancelled) {
        return;
      }

      final result = await devices();
      final paths = result.fold((_) => const <String>[], (value) => value);
      if (cancelled) {
        return;
      }

      for (final path in paths) {
        final devicePath = DBusObjectPath(path);

        // Any device property change reports association state, while the two
        // access point signals report the scan results behind the list.
        deviceSubscriptions.add(
          subscribe(
            devicePath,
            propertiesInterface,
            'PropertiesChanged',
            signature: DBusSignature('sa{sv}as'),
          ),
        );
        deviceSubscriptions.add(
          subscribe(
            devicePath,
            wirelessInterface,
            'AccessPointAdded',
            signature: DBusSignature('o'),
          ),
        );
        deviceSubscriptions.add(
          subscribe(
            devicePath,
            wirelessInterface,
            'AccessPointRemoved',
            signature: DBusSignature('o'),
          ),
        );
      }
    }

    // Step 4: Keep the watches alive for exactly as long as the page listens.
    controller = StreamController<void>.broadcast(
      onListen: () async {
        // Step 4a: The root object carries the radio state and the list of
        // active connections, and reports adapters as they are plugged in.
        rootSubscriptions.add(
          subscribe(
            nmObjectPath,
            propertiesInterface,
            'PropertiesChanged',
            signature: DBusSignature('sa{sv}as'),
          ),
        );
        rootSubscriptions.add(
          subscribe(
            nmObjectPath,
            nmInterface,
            'DeviceAdded',
            signature: DBusSignature('o'),
            onSignal: () => unawaited(subscribeDevices()),
          ),
        );
        rootSubscriptions.add(
          subscribe(
            nmObjectPath,
            nmInterface,
            'DeviceRemoved',
            signature: DBusSignature('o'),
            onSignal: () => unawaited(subscribeDevices()),
          ),
        );

        // Step 4b: The settings registry reports saved profiles being added
        // and removed, including by other clients.
        rootSubscriptions.add(
          subscribe(
            settingsPath,
            settingsInterface,
            'ConnectionAdded',
            signature: DBusSignature('o'),
          ),
        );
        rootSubscriptions.add(
          subscribe(
            settingsPath,
            settingsInterface,
            'ConnectionRemoved',
            signature: DBusSignature('o'),
          ),
        );

        // Step 4c: Finally watch the adapters themselves.
        await subscribeDevices();
      },
      onCancel: () async {
        cancelled = true;
        for (final subscription in rootSubscriptions) {
          await subscription.cancel();
        }
        rootSubscriptions = [];
        for (final subscription in deviceSubscriptions) {
          await subscription.cancel();
        }
        deviceSubscriptions = [];
      },
    );
    return controller.stream;
  }

  /// Requests a scan and returns the visible access points.
  ///
  /// A failed scan request is ignored on purpose: NetworkManager rejects scans
  /// that follow one too closely, and the cached access point list is still
  /// useful. Only reading that list can fail.
  ///
  /// # Returns
  /// One [WifiNetwork] per SSID, strongest access point first.
  ///
  /// # Errors
  /// Returns an [RdeError] when no Wi-Fi device exists or access points cannot
  /// be read.
  Future<Either<RdeError, List<WifiNetwork>>> scanNetworks() {
    return _read('scan for Wi-Fi networks', () async {
      final wifiDevices = await _wifiDevicePaths();
      if (wifiDevices.isEmpty) {
        throw const _WifiException('no Wi-Fi adapter was found');
      }

      final networks = <String, WifiNetwork>{};
      for (final devicePath in wifiDevices) {
        // Step 1: Ask for a scan, but keep going when NetworkManager throttles
        // it and answers with "Scanning not allowed immediately ...".
        try {
          await _call(
            DBusObjectPath(devicePath),
            wirelessInterface,
            'RequestScan',
            [DBusDict(DBusSignature('s'), DBusSignature('v'))],
          );
        } catch (_) {
          // Cached results are used below.
        }

        // Step 2: Give the driver a moment to publish fresh access points.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        // Step 3: Read every access point and keep the strongest one per SSID.
        final accessPoints = await _property(
          DBusObjectPath(devicePath),
          wirelessInterface,
          'AccessPoints',
        );
        for (final apPath in accessPoints.asObjectPathArray()) {
          final network = await _readAccessPoint(apPath);
          if (network == null) {
            continue;
          }
          final existing = networks[network.ssid];
          if (existing == null ||
              _strengthValue(network.strength) >
                  _strengthValue(existing.strength)) {
            networks[network.ssid] = network;
          }
        }
      }

      final list = networks.values.toList()
        ..sort(
          (left, right) =>
              _strengthValue(right.strength)
                  .compareTo(_strengthValue(left.strength)),
        );
      return list;
    });
  }

  /// Returns the network the Wi-Fi device is currently associated with.
  ///
  /// # Returns
  /// The active access point, or `null` when the adapter is disconnected.
  ///
  /// # Errors
  /// Returns an [RdeError] when the adapter state cannot be read.
  Future<Either<RdeError, WifiNetwork?>> currentNetwork() {
    return _read('read the current Wi-Fi network', () async {
      final wifiDevices = await _wifiDevicePaths();
      if (wifiDevices.isEmpty) {
        return null;
      }

      final activePath = await _property(
        DBusObjectPath(wifiDevices.first),
        wirelessInterface,
        'ActiveAccessPoint',
      );
      final path = activePath.asObjectPath().value;
      if (path == '/') {
        return null;
      }
      return _readAccessPoint(DBusObjectPath(path));
    });
  }

  /// Connects to [ssid].
  ///
  /// With a [password], a fresh profile is added and activated through
  /// `AddAndActivateConnection`. Without one, an existing saved profile is
  /// activated; if there is none, the network is treated as open.
  ///
  /// # Errors
  /// Returns an [RdeError] when no Wi-Fi adapter exists, no saved profile
  /// matches, or NetworkManager rejects the connection.
  Future<Either<RdeError, void>> connect(String ssid, {String? password}) {
    return _write('connect to $ssid', () async {
      final devicePath = await _wifiDevicePath();

      if (password != null && password.isNotEmpty) {
        await _addAndActivate(ssid, password, devicePath);
        return;
      }

      final savedPath = await _connectionPathForSsid(ssid);
      if (savedPath != null) {
        await _call(nmObjectPath, nmInterface, 'ActivateConnection', [
          DBusObjectPath(savedPath),
          DBusObjectPath(devicePath),
          DBusObjectPath('/'),
        ]);
        return;
      }

      // No saved profile: activate the network as an open Wi-Fi connection.
      await _addAndActivate(ssid, null, devicePath);
    });
  }

  /// Disconnects the active Wi-Fi connection.
  ///
  /// # Errors
  /// Returns an [RdeError] when no Wi-Fi adapter exists or the device rejects
  /// the request.
  Future<Either<RdeError, void>> disconnect() {
    return _write('disconnect the Wi-Fi network', () async {
      final wifiDevices = await _wifiDevicePaths();
      if (wifiDevices.isEmpty) {
        throw const _WifiException('no Wi-Fi adapter was found');
      }
      for (final devicePath in wifiDevices) {
        await _call(DBusObjectPath(devicePath), deviceInterface, 'Disconnect');
      }
    });
  }

  /// Returns the SSIDs of every stored Wi-Fi profile.
  ///
  /// # Errors
  /// Returns an [RdeError] when the settings registry cannot be read.
  Future<Either<RdeError, List<String>>> savedSsids() {
    return _read('list saved Wi-Fi profiles', () async {
      final ssids = <String>[];
      for (final path in await _connectionPaths()) {
        final settings = await _settingsFor(path);
        if (_settingString(settings, 'connection', 'type') !=
            '802-11-wireless') {
          continue;
        }
        final ssid = _ssidFromSettings(settings);
        if (ssid != null && ssid.isNotEmpty) {
          ssids.add(ssid);
        }
      }
      return ssids;
    });
  }

  /// Deletes the stored profile for [ssid].
  ///
  /// # Errors
  /// Returns an [RdeError] when no saved profile matches or NetworkManager
  /// rejects the deletion.
  Future<Either<RdeError, void>> forget(String ssid) {
    return _write('forget $ssid', () async {
      final path = await _connectionPathForSsid(ssid);
      if (path == null) {
        throw _WifiException('no saved profile matches "$ssid"');
      }
      await _call(DBusObjectPath(path), connectionInterface, 'Delete');
    });
  }

  /// Reads the autoconnect priority of the saved profile for [ssid].
  ///
  /// # Errors
  /// Returns an [RdeError] when no saved profile matches.
  Future<Either<RdeError, int>> priority(String ssid) {
    return _read('read the priority of $ssid', () async {
      final path = await _connectionPathForSsid(ssid);
      if (path == null) {
        throw _WifiException('no saved profile matches "$ssid"');
      }
      final settings = await _settingsFor(path);
      return _settingInt(settings, 'connection', 'autoconnect-priority') ?? 0;
    });
  }

  /// Updates the autoconnect priority of the saved profile for [ssid].
  ///
  /// # Errors
  /// Returns an [RdeError] when no saved profile matches or the update fails.
  Future<Either<RdeError, void>> setPriority(String ssid, int priority) {
    return _write('set the priority of $ssid', () async {
      final path = await _connectionPathForSsid(ssid);
      if (path == null) {
        throw _WifiException('no saved profile matches "$ssid"');
      }

      final settings = await _settingsFor(path);
      final connection = settings.children[DBusString('connection')];
      if (connection is! DBusDict) {
        throw const _WifiException('the saved profile has no connection group');
      }
      connection.children[DBusString('autoconnect-priority')] = DBusVariant(
        DBusInt32(priority),
      );

      await _call(DBusObjectPath(path), connectionInterface, 'Update', [
        settings,
      ]);
    });
  }

  /// Adds and activates a Wi-Fi profile for [ssid].
  Future<void> _addAndActivate(
    String ssid,
    String? password,
    String devicePath,
  ) async {
    final connection = DBusDict.stringVariant({
      'id': DBusString(ssid),
      'type': DBusString('802-11-wireless'),
      'autoconnect': DBusBoolean(true),
    });
    final wireless = DBusDict.stringVariant({
      'ssid': DBusArray.byte(utf8.encode(ssid)),
      'mode': DBusString('infrastructure'),
    });

    final settings = DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), {
      DBusString('connection'): connection,
      DBusString('802-11-wireless'): wireless,
      DBusString('ipv4'): DBusDict.stringVariant({
        'method': DBusString('auto'),
      }),
      DBusString('ipv6'): DBusDict.stringVariant({
        'method': DBusString('auto'),
      }),
      if (password != null && password.isNotEmpty)
        DBusString('802-11-wireless-security'): DBusDict.stringVariant({
          'key-mgmt': DBusString('wpa-psk'),
          'psk': DBusString(password),
        }),
    });

    await _call(nmObjectPath, nmInterface, 'AddAndActivateConnection', [
      settings,
      DBusObjectPath(devicePath),
      DBusObjectPath('/'),
    ]);
  }

  /// Reads one access point, or `null` when it has no visible SSID.
  Future<WifiNetwork?> _readAccessPoint(DBusObjectPath path) async {
    final data = await _allProperties(path, accessPointInterface);

    final ssidValue = data['Ssid'];
    if (ssidValue is! DBusArray || ssidValue.children.isEmpty) {
      return null;
    }
    final ssid = _decodeSsid(ssidValue);
    if (ssid.trim().isEmpty) {
      return null;
    }

    final strength = data['Strength']?.asByte() ?? 0;
    final flags = data['Flags']?.asUint32() ?? 0;
    final wpaFlags = data['WpaFlags']?.asUint32() ?? 0;
    final rsnFlags = data['RsnFlags']?.asUint32() ?? 0;

    return WifiNetwork(
      ssid: ssid,
      security: _securityLabel(flags, wpaFlags, rsnFlags),
      strength: '$strength%',
    );
  }

  /// Maps access point flags onto the label shown in the page.
  String _securityLabel(int flags, int wpaFlags, int rsnFlags) {
    // Step 1: RSN (WPA2/WPA3) is the modern security group.
    if ((rsnFlags & _apSec8021x) != 0) {
      return 'WPA2 Enterprise';
    }
    final hasSae = (rsnFlags & _apSecSae) != 0;
    final hasPsk = (rsnFlags & _apSecPsk) != 0;
    if (hasSae && hasPsk) {
      return 'WPA3/WPA2';
    }
    if (hasSae) {
      return 'WPA3';
    }
    if ((rsnFlags & _apSecOwe) != 0) {
      return 'OWE';
    }
    if (hasPsk) {
      return 'WPA2';
    }

    // Step 2: Older WPA access points.
    if ((wpaFlags & _apSec8021x) != 0) {
      return 'WPA Enterprise';
    }
    if ((wpaFlags & _apSecPsk) != 0) {
      return 'WPA';
    }

    // Step 3: Privacy without a key-management suite is WEP.
    return (flags & _apFlagPrivacy) != 0 ? 'WEP' : 'Open';
  }

  /// Returns the path of the first usable Wi-Fi adapter.
  Future<String> _wifiDevicePath() async {
    final devices = await _wifiDevicePaths();
    if (devices.isEmpty) {
      throw const _WifiException('no Wi-Fi adapter was found');
    }
    return devices.first;
  }

  /// Returns the paths of every device whose type is Wi-Fi.
  Future<List<String>> _wifiDevicePaths() async {
    final response = await _call(nmObjectPath, nmInterface, 'GetDevices');
    final paths = <String>[];

    for (final devicePath in response.returnValues.first.asObjectPathArray()) {
      final type = await _property(devicePath, deviceInterface, 'DeviceType');
      if (type.asUint32() == NmDeviceTypes.wifi) {
        paths.add(devicePath.value);
      }
    }
    return paths;
  }

  /// Returns every stored connection path.
  Future<List<String>> _connectionPaths() async {
    final response = await _call(
      settingsPath,
      settingsInterface,
      'ListConnections',
    );
    return response.returnValues.first
        .asObjectPathArray()
        .map((path) => path.value)
        .toList();
  }

  /// Finds the stored Wi-Fi profile whose SSID is [ssid].
  Future<String?> _connectionPathForSsid(String ssid) async {
    for (final path in await _connectionPaths()) {
      final settings = await _settingsFor(path);
      if (_settingString(settings, 'connection', 'type') != '802-11-wireless') {
        continue;
      }
      if (_ssidFromSettings(settings) == ssid) {
        return path;
      }
    }
    return null;
  }

  /// Reads the settings dictionary of one stored connection.
  Future<DBusDict> _settingsFor(String path) async {
    final response = await _call(
      DBusObjectPath(path),
      connectionInterface,
      'GetSettings',
    );
    final settings = response.returnValues.first;
    if (settings is! DBusDict) {
      throw const _WifiException('the saved profile has an unknown shape');
    }
    return settings;
  }

  /// Reads one string from a stored connection section.
  String? _settingString(DBusDict settings, String section, String key) {
    final value = _settingValue(settings, section, key);
    return value is DBusString ? value.value : null;
  }

  /// Reads one integer from a stored connection section.
  int? _settingInt(DBusDict settings, String section, String key) {
    final value = _settingValue(settings, section, key);
    return value is DBusInt32 ? value.value : null;
  }

  /// Reads the raw value of one stored connection key.
  DBusValue? _settingValue(DBusDict settings, String section, String key) {
    final group = settings.children[DBusString(section)];
    if (group is! DBusDict) {
      return null;
    }
    final value = group.children[DBusString(key)];
    return value is DBusVariant ? value.value : value;
  }

  /// Reads the SSID from a stored connection's `802-11-wireless` group.
  String? _ssidFromSettings(DBusDict settings) {
    final value = _settingValue(settings, '802-11-wireless', 'ssid');
    if (value is! DBusArray) {
      return null;
    }
    return _decodeSsid(value);
  }

  /// Decodes NetworkManager's byte-array SSID representation.
  String _decodeSsid(DBusArray ssid) {
    return utf8.decode(ssid.mapByte().toList(), allowMalformed: true);
  }

  /// Reads every property of [path] exposed by [interface].
  Future<Map<String, DBusValue>> _allProperties(
    DBusObjectPath path,
    String interface,
  ) async {
    final response = await _call(path, propertiesInterface, 'GetAll', [
      DBusString(interface),
    ]);
    final properties = response.returnValues.first;
    if (properties is! DBusDict) {
      throw const _WifiException('the property reply has an unknown shape');
    }
    return properties.mapStringVariant();
  }

  /// Reads one property from [path].
  Future<DBusValue> _property(
    DBusObjectPath path,
    String interface,
    String name,
  ) async {
    final response = await _call(path, propertiesInterface, 'Get', [
      DBusString(interface),
      DBusString(name),
    ]);
    return response.returnValues.first.asVariant();
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

  /// Invokes one NetworkManager method.
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

  /// Parses the percentage string carried by [WifiNetwork.strength].
  int _strengthValue(String strength) {
    return int.tryParse(strength.replaceAll('%', '')) ?? 0;
  }
}

/// Local exception used to abort a NetworkManager operation with context.
class _WifiException implements Exception {
  const _WifiException(this.message);

  final String message;

  @override
  String toString() => message;
}
