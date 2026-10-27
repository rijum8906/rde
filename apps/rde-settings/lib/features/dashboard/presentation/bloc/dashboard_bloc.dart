import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart' as theme_evt;
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/features/dashboard/domain/entities/dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/main.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

/// Drives the dashboard tiles, quick toggles, and personalization shortcuts.
///
/// The appearance controls are deliberately not local-only: the seed color is
/// written to `org.rde.Theme`, which republishes the palette for every themed
/// application on the desktop, and this app follows that publication.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardSettingsUseCase _getSettingsUseCase;
  final SaveDashboardSettingsUseCase _saveSettingsUseCase;
  final UpdateDynamicThemeUseCase _updateDynamicTheme;
  final SetThemeUseCase _setTheme;
  Timer? _statsTimer;

  /// Creates the dashboard bloc.
  ///
  /// [updateDynamicTheme] and [setTheme] reach the `org.rde.Theme` service, so
  /// a seed picked here changes the whole desktop instead of only this app.
  DashboardBloc({
    required this._getSettingsUseCase,
    required this._saveSettingsUseCase,
    required this._updateDynamicTheme,
    required this._setTheme,
  }) : super(DashboardState.initial()) {
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
          themeMode: appThemeBloc.state.themeMode,
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
    appThemeBloc.add(theme_evt.ChangeThemeModeEvent(event.themeMode));
    final newState = state.copyWith(themeMode: event.themeMode);
    emit(newState);
    await _saveDashboardSettings(newState);
  }

  Future<void> _onChangeAccentColor(
    ChangeAccentColorEvent event,
    Emitter<DashboardState> emit,
  ) async {
    // Step 1: Restyle this window immediately, so the picker reacts before the
    // service round trip finishes.
    appThemeBloc.add(theme_evt.ChangeAccentColorEvent(event.accentColor));
    final newState = state.copyWith(accentColor: event.accentColor);
    emit(newState);

    // Step 2: Regenerate the desktop palette from the same seed.
    await _applyDesktopSeed(event.accentColor);

    // Step 3: Keep the dashboard settings in sync with the picked appearance.
    await _saveDashboardSettings(newState);
  }

  /// Re-seeds and activates the `org.rde.Theme` dynamic theme.
  ///
  /// A picked accent color only drives the primary family; the service keeps the
  /// stored secondary, tertiary, and error seeds. The accent is written first and
  /// the dynamic theme is activated afterwards, because a static active theme
  /// keeps its shipped payload and only this application would show the color.
  ///
  /// Failures are logged instead of surfaced: the dashboard stays usable when
  /// the theme service is offline, and the selection made here still applies
  /// to this window.
  Future<void> _applyDesktopSeed(Color accentColor) async {
    // Step 1: Send the color as the primary seed of the dynamic theme.
    final seed = _hexSeed(accentColor);
    final updated = await _updateDynamicTheme(primary: seed);
    final updateFailure = updated.fold((failure) => failure, (_) => null);
    if (updateFailure != null) {
      debugPrint(
        'Unable to re-seed org.rde.Theme with $seed: ${updateFailure.message}',
      );
      return;
    }

    // Step 2: Publish the regenerated palette to the whole desktop.
    final activated = await _setTheme(ThemeManifest.dynamicId);
    activated.fold(
      (failure) => debugPrint(
        'Unable to activate ${ThemeManifest.dynamicId}: ${failure.message}',
      ),
      (_) {},
    );
  }

  /// Formats [color] as the uppercase `#RRGGBB` seed the service accepts.
  String _hexSeed(Color color) {
    final rgb = (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
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
