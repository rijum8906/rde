import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/main.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardSettingsUseCase _getSettingsUseCase;
  final SaveDashboardSettingsUseCase _saveSettingsUseCase;
  Timer? _statsTimer;

  DashboardBloc({
    required GetDashboardSettingsUseCase getSettingsUseCase,
    required SaveDashboardSettingsUseCase saveSettingsUseCase,
  }) : _getSettingsUseCase = getSettingsUseCase,
       _saveSettingsUseCase = saveSettingsUseCase,
       super(DashboardState.initial()) {
    on<DashboardInitEvent>(_onInit);
    on<ToggleWifiEvent>(_onToggleWifi);
    on<ToggleBluetoothEvent>(_onToggleBluetooth);
    on<ChangeVolumeEvent>(_onChangeVolume);
    on<ChangeBrightnessEvent>(_onChangeBrightness);
    on<UpdateSystemStatsEvent>(_onUpdateSystemStats);
    on<ChangeThemeModeEvent>(_onChangeThemeMode);
    on<ChangeAccentColorEvent>(_onChangeAccentColor);

    // Periodically update simulated resource health stats
    _statsTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final newCpu = (0.25 + (timer.tick % 5) * 0.05).clamp(0.0, 1.0);
      final newRam = (0.50 + (timer.tick % 3) * 0.02).clamp(0.0, 1.0);
      final newBattery = (0.88 - (timer.tick * 0.001)).clamp(0.0, 1.0);

      add(
        UpdateSystemStatsEvent(
          cpuUsage: newCpu,
          ramUsage: newRam,
          batteryLevel: newBattery,
        ),
      );
    });
  }

  Future<void> _onInit(
    DashboardInitEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    final result = await _getSettingsUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (settings) => emit(
        state.copyWith(
          status: DashboardStatus.success,
          wifiEnabled: settings.isWifiEnabled,
          bluetoothEnabled: settings.isBluetoothEnabled,
          batteryLevel: settings.batteryLevel,
          ramUsage: settings.ramUsage,
          cpuUsage: 0.38,
          themeMode: themeModeNotifier.value,
          accentColor: accentColorNotifier.value,
        ),
      ),
    );
  }

  Future<void> _onToggleWifi(
    ToggleWifiEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final newState = state.copyWith(wifiEnabled: event.value);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _onToggleBluetooth(
    ToggleBluetoothEvent event,
    Emitter<DashboardState> emit,
  ) async {
    final newState = state.copyWith(bluetoothEnabled: event.value);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _onChangeVolume(
    ChangeVolumeEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(volume: event.value));
  }

  Future<void> _onChangeBrightness(
    ChangeBrightnessEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(brightness: event.value));
  }

  void _onUpdateSystemStats(
    UpdateSystemStatsEvent event,
    Emitter<DashboardState> emit,
  ) {
    emit(
      state.copyWith(
        cpuUsage: event.cpuUsage,
        ramUsage: event.ramUsage,
        batteryLevel: event.batteryLevel,
      ),
    );
  }

  Future<void> _onChangeThemeMode(
    ChangeThemeModeEvent event,
    Emitter<DashboardState> emit,
  ) async {
    themeModeNotifier.value = event.themeMode;
    final newState = state.copyWith(themeMode: event.themeMode);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _onChangeAccentColor(
    ChangeAccentColorEvent event,
    Emitter<DashboardState> emit,
  ) async {
    accentColorNotifier.value = event.accentColor;
    final newState = state.copyWith(accentColor: event.accentColor);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _saveDashboardSettings(DashboardState state) async {
    final settings = DashboardSettings(
      isDarkMode: state.themeMode == ThemeMode.dark,
      isWifiEnabled: state.wifiEnabled,
      isBluetoothEnabled: state.bluetoothEnabled,
      isDndEnabled: false,
      batteryLevel: state.batteryLevel,
      ramUsage: state.ramUsage,
      storageUsage: state.cpuUsage,
    );
    await _saveSettingsUseCase(settings);
  }

  @override
  Future<void> close() {
    _statsTimer?.cancel();
    return super.close();
  }
}
