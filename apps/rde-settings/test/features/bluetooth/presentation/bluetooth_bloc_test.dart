import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_state.dart';

/// Builds a device the way BlueZ describes one.
BluetoothDevice _device(
  String address, {
  String? name,
  bool paired = false,
  bool trusted = false,
  bool connected = false,
  int? rssi,
}) {
  return BluetoothDevice(
    path: '/org/bluez/hci0/dev_${address.replaceAll(':', '_')}',
    address: address,
    name: name ?? address,
    paired: paired,
    trusted: trusted,
    connected: connected,
    servicesResolved: connected,
    rssi: rssi,
  );
}

/// In-memory stand-in for the BlueZ-backed repository.
class _FakeBluetoothRepository implements BluetoothRepository {
  bool hasAdapter = true;
  bool powered = true;
  bool discoverable = false;
  bool discovering = false;
  bool failConnect = false;

  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;

  /// Devices BlueZ would report, mutable so a test can simulate the daemon.
  List<BluetoothDevice> devices = [];

  /// Stands in for the BlueZ signal stream.
  final StreamController<void> changes = StreamController<void>.broadcast();

  /// Pretends BlueZ pushed a change the page has to show.
  void notifyChange() => changes.add(null);

  BluetoothAdapter get _adapter => BluetoothAdapter(
    path: '/org/bluez/hci0',
    address: 'AA:BB:CC:DD:EE:FF',
    name: 'Test Adapter',
    powered: powered,
    discoverable: discoverable,
    discovering: discovering,
  );

  void _update(
    String address,
    BluetoothDevice Function(BluetoothDevice) change,
  ) {
    devices = [
      for (final device in devices)
        if (device.address == address) change(device) else device,
    ];
  }

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<Either<Failure, BluetoothSnapshot>> getSnapshot() async {
    return Right(
      BluetoothSnapshot(
        adapter: hasAdapter ? _adapter : null,
        devices: powered ? List.of(devices) : const [],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> setPowered(bool enabled) async {
    powered = enabled;
    if (!enabled) {
      // BlueZ drops the device objects of a powered-down adapter.
      devices = [];
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setDiscoverable(bool value) async {
    discoverable = value;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> startDiscovery() async {
    startDiscoveryCalls += 1;
    discovering = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> stopDiscovery() async {
    stopDiscoveryCalls += 1;
    discovering = false;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> pair(BluetoothDevice device) async {
    _update(device.address, (value) => value.copyWith(paired: true));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> connect(BluetoothDevice device) async {
    if (failConnect) {
      return Left(Failure('Connection refused by the device.'));
    }
    _update(device.address, (value) => value.copyWith(connected: true));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> disconnect(BluetoothDevice device) async {
    _update(device.address, (value) => value.copyWith(connected: false));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> forget(BluetoothDevice device) async {
    devices = [
      for (final value in devices)
        if (value.address != device.address) value,
    ];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setTrusted(
    BluetoothDevice device,
    bool trusted,
  ) async {
    _update(device.address, (value) => value.copyWith(trusted: trusted));
    return const Right(null);
  }
}

void main() {
  test('init starts a scan and lists what BlueZ knows', () async {
    final repository = _FakeBluetoothRepository()
      ..devices = [
        _device('11:11:11:11:11:11', name: 'Mouse', rssi: -70),
        _device(
          '22:22:22:22:22:22',
          name: 'Headset',
          paired: true,
          connected: true,
        ),
      ];
    final bloc = BluetoothBloc(bluetoothRepository: repository);

    bloc.add(const BluetoothInitEvent());
    final state = await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );

    expect(state.isEnabled, isTrue);
    expect(repository.startDiscoveryCalls, 1);
    expect(state.connectedDevices.single.name, 'Headset');
    // The Available column is the scan list: the connected device is shown in
    // its own column instead of being repeated here.
    expect(
      state.availableDevices.map((device) => device.name),
      isNot(contains('Headset')),
    );
    expect(state.availableDevices.single.name, 'Mouse');

    await bloc.close();
  });

  test('a BlueZ signal refreshes the page without a notice', () async {
    final repository = _FakeBluetoothRepository();
    final bloc = BluetoothBloc(bluetoothRepository: repository);

    bloc.add(const BluetoothInitEvent());
    await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );

    // Another client discovers a device, then the daemon reports it.
    repository.devices = [_device('33:33:33:33:33:33', name: 'Keyboard')];
    final refreshed = bloc.stream.firstWhere(
      (value) => value.devices.isNotEmpty,
    );
    repository.notifyChange();
    final state = await refreshed;

    expect(state.availableDevices.single.name, 'Keyboard');
    expect(state.noticeMessage, isNull);

    await bloc.close();
  });

  test('pairing marks the device paired and notifies once', () async {
    final repository = _FakeBluetoothRepository()
      ..devices = [_device('44:44:44:44:44:44', name: 'Speaker')];
    final bloc = BluetoothBloc(bluetoothRepository: repository);

    bloc.add(const BluetoothInitEvent());
    await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );

    // The notice is raised before the daemon state is read back, so every
    // state is collected and the refreshed one is awaited separately.
    final seen = <BluetoothState>[];
    final subscription = bloc.stream.listen(seen.add);

    bloc.add(const PairDeviceEvent('44:44:44:44:44:44'));
    final refreshed = await bloc.stream.firstWhere(
      (value) => value.pairedDevices.isNotEmpty,
    );

    expect(refreshed.pairedDevices.single.name, 'Speaker');
    expect(
      seen.map((value) => value.noticeMessage),
      contains('Paired with Speaker'),
    );

    await subscription.cancel();
    await bloc.close();
  });

  test('a failed connect reports the error and frees the device', () async {
    final repository = _FakeBluetoothRepository()
      ..devices = [_device('55:55:55:55:55:55', name: 'Phone', paired: true)]
      ..failConnect = true;
    final bloc = BluetoothBloc(bluetoothRepository: repository);

    bloc.add(const BluetoothInitEvent());
    await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );

    final failed = bloc.stream.firstWhere(
      (value) => value.errorMessage != null,
    );
    bloc.add(const ConnectDeviceEvent('55:55:55:55:55:55'));
    final state = await failed;

    expect(state.errorMessage, 'Connection refused by the device.');
    expect(state.busyAddress, isNull);

    await bloc.close();
  });

  test('the scan the page started stops at the end of its window', () async {
    final repository = _FakeBluetoothRepository();
    final bloc = BluetoothBloc(
      bluetoothRepository: repository,
      scanWindow: const Duration(milliseconds: 20),
    );

    bloc.add(const BluetoothInitEvent());
    await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );
    expect(repository.discovering, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(repository.stopDiscoveryCalls, 1);
    expect(bloc.state.isDiscovering, isFalse);
    // The end of the window is not a user action, so nothing is announced.
    expect(bloc.state.noticeMessage, isNull);

    await bloc.close();
  });

  test('leaving the page stops the scan it started', () async {
    final repository = _FakeBluetoothRepository();
    final bloc = BluetoothBloc(bluetoothRepository: repository);

    bloc.add(const BluetoothInitEvent());
    await bloc.stream.firstWhere(
      (value) => value.status == BluetoothStatus.success,
    );

    await bloc.close();

    expect(repository.stopDiscoveryCalls, 1);
  });
}
