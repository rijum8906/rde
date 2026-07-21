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

class ChangeVolumeEvent extends DashboardEvent {
  final double value;
  const ChangeVolumeEvent(this.value);
}

class ChangeBrightnessEvent extends DashboardEvent {
  final double value;
  const ChangeBrightnessEvent(this.value);
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

class ChangeThemeModeEvent extends DashboardEvent {
  final ThemeMode themeMode;
  const ChangeThemeModeEvent(this.themeMode);
}

class ChangeAccentColorEvent extends DashboardEvent {
  final Color accentColor;
  const ChangeAccentColorEvent(this.accentColor);
}
