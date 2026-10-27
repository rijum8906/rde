import 'dart:async';

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
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_state.dart';

/// In-memory stand-in for the UPower-backed repository.
///
/// The fields are the daemon's state: a mutation writes them, so a following
/// read observes the change exactly like the real daemons behave.
class _FakeBatteryRepository implements BatteryHealthRepository {
  double percentage = 72;
  String? activePowerProfile = 'balanced';
  bool thresholdSupported = true;
  bool thresholdEnabled = false;
  int chargeEndThreshold = 80;

  int setChargeThresholdCalls = 0;
  int setChargeEndThresholdCalls = 0;
  int setPowerProfileCalls = 0;

  /// Stands in for the UPower and power-profiles-daemon signal streams.
  final StreamController<void> changes = StreamController<void>.broadcast();

  /// Pretends a daemon pushed a change the page has to show.
  void notifyChange() => changes.add(null);

  BatterySnapshot get _snapshot => BatterySnapshot(
    percentage: percentage,
    state: 2,
    healthPercent: 94,
    cycleCount: 248,
    temperatureCelsius: 31,
    timeToEmptySeconds: 3600,
    timeToFullSeconds: 0,
    energyFullWh: 45,
    energyFullDesignWh: 48,
    chargeThresholdSupported: thresholdSupported,
    chargeThresholdEnabled: thresholdEnabled,
    chargeEndThreshold: chargeEndThreshold,
    chargeStartThreshold: 60,
    model: 'Test Battery',
    vendor: 'Test',
    activePowerProfile: activePowerProfile,
  );

  @override
  Stream<void> watchChanges() => changes.stream;

  @override
  Future<Either<Failure, BatterySnapshot>> getSnapshot() async =>
      Right(_snapshot);

  @override
  Future<Either<Failure, void>> setChargeThresholdEnabled(bool enabled) async {
    setChargeThresholdCalls += 1;
    thresholdEnabled = enabled;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setChargeEndThreshold(int percent) async {
    setChargeEndThresholdCalls += 1;
    chargeEndThreshold = percent;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setPowerProfile(String profile) async {
    setPowerProfileCalls += 1;
    activePowerProfile = profile;
    return const Right(null);
  }
}

BatteryHealthBloc _bloc(BatteryHealthRepository repository) {
  return BatteryHealthBloc(
    read: ReadBatteryHealthUseCase(repository),
    watch: WatchBatteryHealthUseCase(repository),
    setChargeThreshold: SetChargeThresholdUseCase(repository),
    setChargeEndThreshold: SetChargeEndThresholdUseCase(repository),
    setPowerProfile: SetPowerProfileUseCase(repository),
  );
}

Future<void> _init(BatteryHealthBloc bloc) {
  bloc.add(const BatteryHealthInitEvent());
  return bloc.stream.firstWhere(
    (value) => value.status == BatteryHealthStatus.success,
  );
}

void main() {
  test('init shows the battery and the profile the daemon reports', () async {
    final repository = _FakeBatteryRepository()
      ..activePowerProfile = 'power-saver';
    final bloc = _bloc(repository);

    await _init(bloc);
    final state = bloc.state;

    expect(state.snapshot?.percentage, 72);
    // The switch follows the daemon's profile instead of the user's last tap.
    expect(state.powerSaverActive, isTrue);

    await bloc.close();
  });

  test('a daemon signal refreshes the page after the burst settles', () async {
    final repository = _FakeBatteryRepository();
    final bloc = _bloc(repository);

    await _init(bloc);

    // UPower reports a lower charge; the page has to follow without a reload.
    repository.percentage = 40;
    final refreshed = bloc.stream.firstWhere(
      (value) => value.snapshot?.percentage == 40,
    );
    repository.notifyChange();

    final state = await refreshed;

    expect(state.snapshot?.percentage, 40);
    expect(state.errorMessage, isNull);

    await bloc.close();
  });

  test('turning on health protection re-reads the daemon state', () async {
    final repository = _FakeBatteryRepository();
    final bloc = _bloc(repository);

    await _init(bloc);

    final toggled = bloc.stream.firstWhere(
      (value) => value.snapshot?.chargeThresholdEnabled == true,
    );
    bloc.add(const ToggleHealthProtectionEvent(true));
    final state = await toggled;

    expect(repository.setChargeThresholdCalls, 1);
    expect(state.isBusy, isFalse);

    await bloc.close();
  });

  test('switching to power saver reads the active profile back', () async {
    final repository = _FakeBatteryRepository();
    final bloc = _bloc(repository);

    await _init(bloc);

    final toggled = bloc.stream.firstWhere(
      (value) => value.powerSaverActive && !value.isBusy,
    );
    bloc.add(const TogglePowerSavingEvent(true));
    final state = await toggled;

    expect(repository.setPowerProfileCalls, 1);
    expect(state.snapshot?.activePowerProfile, 'power-saver');

    await bloc.close();
  });

  test('leaving the page stops listening for daemon signals', () async {
    final repository = _FakeBatteryRepository();
    final bloc = _bloc(repository);

    await _init(bloc);
    expect(repository.changes.hasListener, isTrue);

    await bloc.close();

    expect(repository.changes.hasListener, isFalse);
  });
}
