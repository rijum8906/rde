import 'package:core/theme.dart';
import 'package:flutter/material.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState {
  final DashboardStatus status;
  final bool wifiEnabled;
  final bool bluetoothEnabled;
  final double volume;
  final double brightness;
  final double cpuUsage;
  final double ramUsage;
  final double batteryLevel;
  final AppearanceMode appearanceMode;
  final Color accentColor;
  final String? errorMessage;

  const DashboardState({
    required this.status,
    required this.wifiEnabled,
    required this.bluetoothEnabled,
    required this.volume,
    required this.brightness,
    required this.cpuUsage,
    required this.ramUsage,
    required this.batteryLevel,
    required this.appearanceMode,
    required this.accentColor,
    this.errorMessage,
  });

  factory DashboardState.initial() {
    return const DashboardState(
      status: DashboardStatus.initial,
      wifiEnabled: true,
      bluetoothEnabled: false,
      volume: 0.7,
      brightness: 0.65,
      cpuUsage: 0.38,
      ramUsage: 0.54,
      batteryLevel: 0.88,
      appearanceMode: AppearanceMode.light,
      accentColor: Color(0xFF6750A4),
    );
  }

  DashboardState copyWith({
    DashboardStatus? status,
    bool? wifiEnabled,
    bool? bluetoothEnabled,
    double? volume,
    double? brightness,
    double? cpuUsage,
    double? ramUsage,
    double? batteryLevel,
    AppearanceMode? appearanceMode,
    Color? accentColor,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      wifiEnabled: wifiEnabled ?? this.wifiEnabled,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      ramUsage: ramUsage ?? this.ramUsage,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      appearanceMode: appearanceMode ?? this.appearanceMode,
      accentColor: accentColor ?? this.accentColor,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          wifiEnabled == other.wifiEnabled &&
          bluetoothEnabled == other.bluetoothEnabled &&
          volume == other.volume &&
          brightness == other.brightness &&
          cpuUsage == other.cpuUsage &&
          ramUsage == other.ramUsage &&
          batteryLevel == other.batteryLevel &&
          appearanceMode == other.appearanceMode &&
          accentColor == other.accentColor &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      wifiEnabled.hashCode ^
      bluetoothEnabled.hashCode ^
      volume.hashCode ^
      brightness.hashCode ^
      cpuUsage.hashCode ^
      ramUsage.hashCode ^
      batteryLevel.hashCode ^
      appearanceMode.hashCode ^
      accentColor.hashCode ^
      errorMessage.hashCode;
}
