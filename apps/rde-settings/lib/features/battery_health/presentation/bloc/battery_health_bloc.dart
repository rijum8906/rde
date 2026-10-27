import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/battery_health/domain/entities/battery_snapshot.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/read_battery_health.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_end_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_power_profile.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/watch_battery_health.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_event.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_state.dart';

/// Coordinates the Battery Health page with the UPower-backed repository.
///
/// Every mutation is followed by a fresh read, so the page renders the daemon's
/// state instead of an optimistic guess: the charge threshold and the active
/// power profile are both owned by the daemons and can be changed by another
/// client while the page is open.
class BatteryHealthBloc extends Bloc<BatteryHealthEvent, BatteryHealthState> {
  BatteryHealthBloc({
    required this._read,
    required this._watch,
    required this._setChargeThreshold,
    required this._setChargeEndThreshold,
    required this._setPowerProfile,
  }) : super(const BatteryHealthState()) {
    on<BatteryHealthInitEvent>(_onInit);
    on<BatteryHealthServiceChangedEvent>(_onServiceChanged);
    on<BatteryHealthRefreshEvent>(_onRefresh);
    on<TogglePowerSavingEvent>(_onTogglePowerSaving);
    on<ToggleHealthProtectionEvent>(_onToggleHealthProtection);
    on<ChangeChargeLimitEvent>(_onChangeChargeLimit);

    // UPower owns the battery and power-profiles-daemon owns the profile, and
    // another client - the desktop shell, `upower`, `powerprofilesctl` - can
    // change either while the page is open. Listening from the constructor
    // keeps the page showing the daemon's state even before the first read
    // finishes.
    _changes = _watch().listen(
      (_) => add(const BatteryHealthServiceChangedEvent()),
      onError: (Object _) {},
    );
  }

  final ReadBatteryHealthUseCase _read;
  final WatchBatteryHealthUseCase _watch;
  final SetChargeThresholdUseCase _setChargeThreshold;
  final SetChargeEndThresholdUseCase _setChargeEndThreshold;
  final SetPowerProfileUseCase _setPowerProfile;

  /// Live updates pushed by the daemons while the page is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of daemon signals into a single refresh.
  Timer? _changeDebounce;

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    await _changes.cancel();
    return super.close();
  }

  Future<void> _onInit(
    BatteryHealthInitEvent event,
    Emitter<BatteryHealthState> emit,
  ) async {
    emit(state.copyWith(status: BatteryHealthStatus.loading, clearError: true));

    final result = await _read();
    Failure? failure;
    BatterySnapshot? snapshot;
    result.fold((value) => failure = value, (value) => snapshot = value);

    if (failure != null) {
      emit(
        state.copyWith(
          status: BatteryHealthStatus.failure,
          errorMessage: failure!.message,
        ),
      );
      return;
    }

    final loaded = snapshot!;
    emit(
      state.copyWith(
        status: BatteryHealthStatus.success,
        snapshot: loaded,
        powerSaverActive: loaded.isPowerSaver,
        clearError: true,
      ),
    );
  }

  /// Collapses a burst of daemon signals into a single refresh.
  ///
  /// One battery action produces several signals - a charge level ticks once
  /// per percent - so the refresh waits for the burst to settle. The page keeps
  /// showing its current content until then, and a user action in flight is
  /// left alone because it refreshes when it finishes.
  ///
  /// The timer only dispatches [BatteryHealthRefreshEvent]: this handler
  /// returns synchronously, so its emitter is already completed by the time the
  /// timer fires, and the refresh is awaited by the event handler instead.
  void _onServiceChanged(
    BatteryHealthServiceChangedEvent event,
    Emitter<BatteryHealthState> emit,
  ) {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (state.isBusy) {
        return;
      }
      add(const BatteryHealthRefreshEvent());
    });
  }

  Future<void> _onRefresh(
    BatteryHealthRefreshEvent event,
    Emitter<BatteryHealthState> emit,
  ) async {
    await _refresh(emit);
  }

  Future<void> _onTogglePowerSaving(
    TogglePowerSavingEvent event,
    Emitter<BatteryHealthState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, clearError: true));
    final result = await _setPowerProfile(
      event.enabled ? 'power-saver' : 'balanced',
    );
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit, isBusy: false);
  }

  Future<void> _onToggleHealthProtection(
    ToggleHealthProtectionEvent event,
    Emitter<BatteryHealthState> emit,
  ) async {
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    emit(state.copyWith(isBusy: true, clearError: true));
    final result = await _setChargeThreshold(
      current: snapshot,
      enabled: event.enabled,
    );
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit, isBusy: false);
  }

  Future<void> _onChangeChargeLimit(
    ChangeChargeLimitEvent event,
    Emitter<BatteryHealthState> emit,
  ) async {
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    final percent = (event.fraction * 100).round();
    emit(state.copyWith(isBusy: true, clearError: true));
    final result = await _setChargeEndThreshold(
      current: snapshot,
      percent: percent,
    );
    final failure = _failureOf(result);
    if (failure != null) {
      emit(state.copyWith(isBusy: false, errorMessage: failure.message));
      return;
    }

    await _refresh(emit, isBusy: false);
  }

  /// Reads the battery and the active power profile back from the daemons.
  ///
  /// A failed read keeps the content the page already shows and only reports
  /// the error, because a transient daemon error should not blank the page.
  Future<void> _refresh(
    Emitter<BatteryHealthState> emit, {
    bool? isBusy,
  }) async {
    final result = await _read();
    Failure? failure;
    BatterySnapshot? snapshot;
    result.fold((value) => failure = value, (value) => snapshot = value);

    if (failure != null) {
      emit(state.copyWith(errorMessage: failure!.message, isBusy: isBusy));
      return;
    }

    final loaded = snapshot!;
    emit(
      state.copyWith(
        status: BatteryHealthStatus.success,
        snapshot: loaded,
        powerSaverActive: loaded.isPowerSaver,
        clearError: true,
        isBusy: isBusy,
      ),
    );
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
