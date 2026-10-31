import 'package:core/core.dart';
import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/master_volume_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_personalization.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_system_health.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';

import '../../theme_styling/theme_test_harness.dart';

/// In-memory stand-in for the NetworkManager-backed repository.
class _FakeWifiRepository implements WifiRepository {
  bool enabled = true;

  final List<String> calls = [];

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();

  @override
  Future<Either<Failure, List<WifiNetwork>>> scanNetworks() async =>
      const Right([]);

  @override
  Future<Either<Failure, WifiNetwork>> connectToNetwork(
    WifiNetwork network, {
    String? password,
  }) async => Right(network);

  @override
  Future<Either<Failure, void>> disconnectFromNetwork(
    WifiNetwork network,
  ) async => const Right(null);

  @override
  Future<Either<Failure, void>> forgetNetwork(WifiNetwork network) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<WifiNetwork>>> getSavedNetworks() async =>
      const Right([]);

  @override
  Future<Either<Failure, WifiNetwork?>> getCurrentNetwork() async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setNetworkPriority(
    WifiNetwork network,
    int priority,
  ) async => const Right(null);

  @override
  Future<Either<Failure, int>> getNetworkPriority(
    WifiNetwork network,
  ) async => const Right(0);

  @override
  Future<Either<Failure, bool>> isWifiEnabled() async => Right(enabled);

  @override
  Future<Either<Failure, void>> setWifiEnabled(bool value) async {
    calls.add('setWifiEnabled:$value');
    enabled = value;
    return const Right(null);
  }
}

/// In-memory stand-in for the BlueZ-backed repository.
class _FakeBluetoothRepository implements BluetoothRepository {
  bool powered = true;
  bool available = true;

  final List<String> calls = [];

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();

  @override
  Future<Either<Failure, BluetoothSnapshot>> getSnapshot() async {
    return Right(
      BluetoothSnapshot(
        adapter: available
            ? BluetoothAdapter(
                path: '/org/bluez/hci0',
                address: 'AA:BB:CC:DD:EE:FF',
                name: 'Test Adapter',
                powered: powered,
                discoverable: false,
                discovering: false,
              )
            : null,
        devices: const [],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> setPowered(bool value) async {
    calls.add('setPowered:$value');
    powered = value;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setDiscoverable(bool discoverable) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> startDiscovery() async => const Right(null);

  @override
  Future<Either<Failure, void>> stopDiscovery() async => const Right(null);

  @override
  Future<Either<Failure, void>> pair(BluetoothDevice device) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> connect(BluetoothDevice device) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> disconnect(BluetoothDevice device) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> forget(BluetoothDevice device) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setTrusted(
    BluetoothDevice device,
    bool trusted,
  ) async => const Right(null);
}

/// In-memory stand-in for the `org.rde.Volume` repository.
class _FakeVolumeRepository implements MasterVolumeRepository {
  int volume = 42;

  @override
  Future<Either<Failure, MasterVolume>> read() async {
    return Right(
      MasterVolume(
        volume: volume,
        muted: false,
        step: 5,
        minVolume: 0,
        maxVolume: 100,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> setVolume(int value) async {
    volume = value;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setMuted(bool muted) async =>
      const Right(null);

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

/// Builds and owns the blocs the dashboard cards read from.
class _Harness {
  _Harness() {
    wifiBloc = WifiBloc(wifiRepository: wifi);
    bluetoothBloc = BluetoothBloc(bluetoothRepository: bluetooth);
    volumeBloc = VolumeBloc(repository: volume);
    themeBloc = ThemeBloc(repository: themes);
  }

  final _FakeWifiRepository wifi = _FakeWifiRepository();
  final _FakeBluetoothRepository bluetooth = _FakeBluetoothRepository();
  final _FakeVolumeRepository volume = _FakeVolumeRepository();
  final FakeThemeRepository themes = FakeThemeRepository();

  late final WifiBloc wifiBloc;
  late final BluetoothBloc bluetoothBloc;
  late final VolumeBloc volumeBloc;
  late final ThemeBloc themeBloc;

  /// Pumps [child] with every dashboard bloc loaded from the fakes.
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wifiBloc),
          BlocProvider.value(value: bluetoothBloc),
          BlocProvider.value(value: volumeBloc),
          BlocProvider.value(value: themeBloc),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );

    // The dashboard page adds these when it creates the blocs.
    wifiBloc.add(const WifiInitEvent());
    bluetoothBloc.add(const BluetoothInitEvent());
    volumeBloc.add(const VolumeInitEvent());
    themeBloc.add(const ThemeInitEvent());
    await tester.pumpAndSettle();
  }

  /// Releases the blocs and their repositories.
  Future<void> dispose() async {
    await wifiBloc.close();
    await bluetoothBloc.close();
    await volumeBloc.close();
    await themeBloc.close();
    await themes.dispose();
  }
}

/// Finds a preset accent dot by the color it paints.
Finder _accentDot(Color color) {
  return find.byWidgetPredicate((widget) {
    if (widget is! AnimatedContainer) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

void main() {
  group('DashboardQuickActions', () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.dispose());

    testWidgets('reads volume and brightness from their sources', (
      tester,
    ) async {
      await harness.pump(tester, const DashboardQuickActions());
      debugPrint('VOL=${harness.volumeBloc.state.master?.volume} '
          'WIFI=${harness.wifiBloc.state.isWifiEnabled}');

      // Step 1: Volume comes from the volume service, brightness is local.
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);

      // Step 2: The volume icon reflects the reported level.
      expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Wi-Fi tile switches the radio through WifiBloc', (
      tester,
    ) async {
      await harness.pump(tester, const DashboardQuickActions());
      expect(find.byIcon(Icons.wifi), findsOneWidget);

      await tester.tap(find.byIcon(Icons.wifi));
      await tester.pumpAndSettle();

      expect(harness.wifi.calls, contains('setWifiEnabled:false'));
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Bluetooth tile switches the radio through BluetoothBloc', (
      tester,
    ) async {
      await harness.pump(tester, const DashboardQuickActions());
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bluetooth));
      await tester.pumpAndSettle();

      expect(harness.bluetooth.calls, contains('setPowered:false'));
      expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the appearance tile switches the mode through ThemeBloc', (
      tester,
    ) async {
      await harness.pump(tester, const DashboardQuickActions());

      // The fake service starts in dark mode, so the tile shows a dark icon.
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);

      await tester.tap(find.byIcon(Icons.dark_mode));
      await tester.pumpAndSettle();

      expect(harness.themes.calls, contains('setMode:light'));
      expect(find.byIcon(Icons.light_mode), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('DashboardPersonalization', () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.dispose());

    testWidgets('selects the appearance the service reports', (tester) async {
      await harness.pump(tester, const DashboardPersonalization());

      final segmented = tester.widget<SegmentedButton<AppearanceMode>>(
        find.byType(SegmentedButton<AppearanceMode>),
      );
      expect(segmented.selected, {AppearanceMode.dark});
    });

    testWidgets('picking another appearance writes it to the service', (
      tester,
    ) async {
      await harness.pump(tester, const DashboardPersonalization());

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(harness.themes.calls, contains('setMode:light'));
    });

    testWidgets('picking an accent re-seeds through ThemeBloc', (tester) async {
      await harness.pump(tester, const DashboardPersonalization());

      await tester.tap(_accentDot(const Color(0xFF006E3C)));
      await tester.pumpAndSettle();

      expect(
        harness.themes.calls,
        contains('updateDynamicTheme:#006E3C:::'),
      );
      expect(harness.themes.dynamicSeeds.primary, '#006E3C');
    });
  });

  group('DashboardSystemHealth', () {
    testWidgets('renders the gauges and samples them over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardSystemHealth())),
      );

      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('RAM'), findsOneWidget);
      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);

      // The local sample ticks every four seconds.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('30%'), findsOneWidget);

      // Disposing the widget cancels the sample timer.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
