import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/repositories/battery_health_repository.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/read_battery_health.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_end_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_power_profile.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/watch_battery_health.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_event.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/health_state_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/visual_battery_card.dart';

/// The battery the introspect of `battery_BAT0` describes.
final _snapshot = BatterySnapshot(
  percentage: 18,
  state: 1,
  healthPercent: 99.55,
  cycleCount: 408,
  temperatureCelsius: null,
  timeToEmptySeconds: 0,
  timeToFullSeconds: 3962,
  energyFullWh: 59.73,
  energyFullDesignWh: 60,
  chargeThresholdSupported: true,
  chargeThresholdEnabled: false,
  chargeEndThreshold: 0,
  chargeStartThreshold: 0,
  model: 'L24B3PK2',
  vendor: 'BYD',
);

class _FakeBatteryRepository implements BatteryHealthRepository {
  @override
  Stream<void> watchChanges() => const Stream<void>.empty();

  @override
  Future<Either<Failure, BatterySnapshot>> getSnapshot() async =>
      Right(_snapshot);

  @override
  Future<Either<Failure, void>> setChargeThresholdEnabled(bool enabled) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setChargeEndThreshold(int percent) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setPowerProfile(String profile) async =>
      const Right(null);
}

void main() {
  Future<void> pumpCards(WidgetTester tester) async {
    final repository = _FakeBatteryRepository();
    final bloc = BatteryHealthBloc(
      read: ReadBatteryHealthUseCase(repository),
      watch: WatchBatteryHealthUseCase(repository),
      setChargeThreshold: SetChargeThresholdUseCase(repository),
      setChargeEndThreshold: SetChargeEndThresholdUseCase(repository),
      setPowerProfile: SetPowerProfileUseCase(repository),
    )..add(const BatteryHealthInitEvent());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<BatteryHealthBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [VisualBatteryCard(), HealthStatsCard()]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the cylinder shows the charge the daemon reports', (
    tester,
  ) async {
    await pumpCards(tester);

    // 18 %, not the 88 % placeholder.
    expect(find.text('18%'), findsOneWidget);
    expect(find.text('88%'), findsNothing);
  });

  testWidgets('the status line shows the real time estimate', (tester) async {
    await pumpCards(tester);

    expect(find.text('1h 6m until full'), findsOneWidget);
    expect(find.text('Charging'), findsOneWidget);
  });

  testWidgets('the health rows show the reported capacity and cycles', (
    tester,
  ) async {
    await pumpCards(tester);

    expect(find.text('408 cycles'), findsOneWidget);
    expect(find.text('Optimized'), findsOneWidget);
    // The battery reports Temperature = 0, which means "no sensor".
    expect(find.text('Unknown'), findsOneWidget);
  });
}
