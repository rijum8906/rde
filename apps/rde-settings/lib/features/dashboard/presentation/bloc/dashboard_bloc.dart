import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart' as theme_evt;
import 'package:core/theme.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/main.dart';

import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardSettingsUseCase _getSettingsUseCase;
  final SaveDashboardSettingsUseCase _saveSettingsUseCase;
  final UpdateDynamicThemeUseCase _updateDynamicTheme;
  final SetThemeUseCase _setThemeUseCase;
  final SetModeUseCase _setModeUseCase;
  Timer? _statsTimer;

  DashboardBloc({
    required this._getSettingsUseCase,
    required this._saveSettingsUseCase,
    required this._updateDynamicTheme,
    required this._setThemeUseCase,
    required this._setModeUseCase,
  }) : super(DashboardState.initial()) {
    on<DashboardInitEvent>(_onInit);
    on<ToggleWifiEvent>(_onToggleWifi);
    on<ToggleBluetoothEvent>(_onToggleBluetooth);
    on<SetDashboardVolumeEvent>(_onSetVolume);
    on<SetDashboardBrightnessEvent>(_onSetBrightness);
    on<UpdateSystemStatsEvent>(_onUpdateSystemStats);
    on<ChangeThemeAppearanceEvent>(_onChangeThemeAppearance);
    on<ChangeAccentColorEvent>(_onChangeAccentColor);

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
          appearanceMode: appThemeBloc.state.appearanceMode,
          accentColor: appThemeBloc.state.accentColor,
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

  Future<void> _onSetVolume(
    SetDashboardVolumeEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(volume: event.value));
  }

  Future<void> _onSetBrightness(
    SetDashboardBrightnessEvent event,
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

  Future<void> _onChangeThemeAppearance(
    ChangeThemeAppearanceEvent event,
    Emitter<DashboardState> emit,
  ) async {
    appThemeBloc.add(theme_evt.ChangeThemeModeEvent(event.appearanceMode));

    // FIXED: Used event.appearanceMode instead of hardcoding AppearanceMode.light
    final newState = state.copyWith(appearanceMode: event.appearanceMode);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _onChangeAccentColor(
    ChangeAccentColorEvent event,
    Emitter<DashboardState> emit,
  ) async {
    appThemeBloc.add(theme_evt.ChangeAccentColorEvent(event.accentColor));
    final newState = state.copyWith(accentColor: event.accentColor);
    emit(newState);

    await _applyDesktopSeed(event.accentColor);
    await _saveDashboardSettings(newState);
  }

  Future<void> _applyDesktopSeed(Color accentColor) async {
    final seed = _hexSeed(accentColor);
    final updated = await _updateDynamicTheme(primary: seed);
    final updateFailure = updated.fold((failure) => failure, (_) => null);
    if (updateFailure != null) {
      debugPrint(
        'Unable to re-seed org.rde.Theme with $seed: ${updateFailure.message}',
      );
      return;
    }

    final activated = await _setThemeUseCase(ThemeManifest.dynamicId);
    activated.fold(
      (failure) => debugPrint(
        'Unable to activate ${ThemeManifest.dynamicId}: ${failure.message}',
      ),
      (_) {},
    );
  }

  String _hexSeed(Color color) {
    final rgb = (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
  }

  Future<void> _saveDashboardSettings(DashboardState state) async {
    final settings = DashboardSettings(
      isDarkMode: state.appearanceMode == AppearanceMode.dark,
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
