import 'package:core/theme/domain/entities/appearance_mode.dart';
import 'package:flutter/material.dart';

abstract class DashboardEvent {
  const DashboardEvent();
}

class DashboardInitEvent extends DashboardEvent {
  const DashboardInitEvent();
}

class ToggleWifiEvent extends DashboardEvent {
  final bool value;
  const ToggleWifiEvent(this.value);
}

class ToggleBluetoothEvent extends DashboardEvent {
  final bool value;
  const ToggleBluetoothEvent(this.value);
}

/// Renamed to avoid conflict with the system's volume service
class SetDashboardVolumeEvent extends DashboardEvent {
  final double value;
  const SetDashboardVolumeEvent(this.value);
}

/// Renamed to avoid conflict with the system's brightness service
class SetDashboardBrightnessEvent extends DashboardEvent {
  final double value;
  const SetDashboardBrightnessEvent(this.value);
}

class UpdateSystemStatsEvent extends DashboardEvent {
  final double cpuUsage;
  final double ramUsage;
  final double batteryLevel;
  const UpdateSystemStatsEvent({
    required this.cpuUsage,
    required this.ramUsage,
    required this.batteryLevel,
  });
}

class ChangeThemeAppearanceEvent extends DashboardEvent {
  final AppearanceMode appearanceMode;
  const ChangeThemeAppearanceEvent(this.appearanceMode);
}

class ChangeAccentColorEvent extends DashboardEvent {
  final Color accentColor;
  const ChangeAccentColorEvent(this.accentColor);
}
