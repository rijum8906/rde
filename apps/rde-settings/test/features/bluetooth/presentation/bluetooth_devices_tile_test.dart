import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_devices_tile.dart';

/// In-memory BlueZ stand-in that records the disconnect the page requests.
class _FakeBluetoothRepository implements BluetoothRepository {
  BluetoothDevice device = BluetoothDevice(
    path: '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF',
    address: 'AA:BB:CC:DD:EE:FF',
    name: 'Headset',
    paired: true,
    trusted: true,
    connected: true,
    servicesResolved: true,
  );

  int disconnectCalls = 0;

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();

  @override
  Future<Either<Failure, BluetoothSnapshot>> getSnapshot() async {
    return Right(
      BluetoothSnapshot(
        adapter: BluetoothAdapter(
          path: '/org/bluez/hci0',
          address: '00:11:22:33:44:55',
          name: 'Test Adapter',
          powered: true,
          discoverable: false,
          discovering: false,
        ),
        devices: [device],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> disconnect(BluetoothDevice target) async {
    disconnectCalls += 1;
    device = device.copyWith(connected: false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setPowered(bool enabled) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setDiscoverable(bool discoverable) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> startDiscovery() async => const Right(null);

  @override
  Future<Either<Failure, void>> stopDiscovery() async => const Right(null);

  @override
  Future<Either<Failure, void>> pair(BluetoothDevice target) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> connect(BluetoothDevice target) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> forget(BluetoothDevice target) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setTrusted(
    BluetoothDevice target,
    bool trusted,
  ) async => const Right(null);
}

void main() {
  testWidgets('a connected device row disconnects the device', (tester) async {
    final repository = _FakeBluetoothRepository();
    final bloc = BluetoothBloc(bluetoothRepository: repository);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<BluetoothBloc>.value(
          value: bloc,
          child: Scaffold(body: BluetoothDeviceTile(device: repository.device)),
        ),
      ),
    );

    // The page reads the device tree on open, so the row has a device to act on.
    bloc.add(const BluetoothInitEvent());
    await tester.pumpAndSettle();

    // Connected devices offer Disconnect instead of Connect.
    final disconnect = find.widgetWithText(TextButton, 'Disconnect');
    expect(disconnect, findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsNothing);

    await tester.tap(disconnect);
    await tester.pumpAndSettle();

    expect(repository.disconnectCalls, 1);
    expect(bloc.state.connectedDevices, isEmpty);
  });
}
