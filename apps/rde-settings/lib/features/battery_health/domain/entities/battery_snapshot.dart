import 'package:equatable/equatable.dart';

/// One reading of the battery, mirroring the subset of
/// `org.freedesktop.UPower.Device` that the Battery Health page renders.
///
/// Every field except `percentage` and `state` is nullable, because UPower
/// reports `0` / `-1` for "unknown" on some hardware (e.g. `Temperature = 0`
/// on machines without a temp sensor, `ChargeCycles = -1` on batteries that
/// don't expose it). The domain uses `null` for "unknown" so the UI can
/// render "Unknown" instead of a misleading zero.
class BatterySnapshot extends Equatable {
  const BatterySnapshot({
    required this.percentage,
    required this.state,
    required this.healthPercent,
    required this.cycleCount,
    required this.temperatureCelsius,
    required this.timeToEmptySeconds,
    required this.timeToFullSeconds,
    required this.energyFullWh,
    required this.energyFullDesignWh,
    required this.chargeThresholdSupported,
    required this.chargeThresholdEnabled,
    required this.chargeEndThreshold,
    required this.chargeStartThreshold,
    required this.model,
    required this.vendor,
    this.activePowerProfile,
  });

  final double percentage;
  final int state;
  final double? healthPercent;
  final int? cycleCount;
  final double? temperatureCelsius;
  final int timeToEmptySeconds;
  final int timeToFullSeconds;
  final double energyFullWh;
  final double energyFullDesignWh;
  final bool chargeThresholdSupported;
  final bool chargeThresholdEnabled;
  final int chargeEndThreshold;
  final int chargeStartThreshold;
  final String model;
  final String vendor;

  /// The power profile the daemon reports as active (`performance`,
  /// `balanced`, or `power-saver`), or `null` when power-profiles-daemon is
  /// not running.
  ///
  /// This comes from `org.freedesktop.UPower.PowerProfiles`, not from the
  /// battery device itself, and is attached by the datasource when a snapshot
  /// is read.
  final String? activePowerProfile;

  bool get isCharging => state == 1 || state == 4;
  bool get isDischarging => state == 2;

  bool get isPowerSaver => activePowerProfile == 'power-saver';

  String get deviceStatusLabel {
    final h = healthPercent;
    if (h == null) return 'Unknown';
    if (h >= 80) return 'Optimized';
    if (h >= 50) return 'Service soon';
    return 'Replace';
  }

  String get deviceStatusDescription {
    final h = healthPercent;
    if (h == null) return 'Health data not reported by this battery';
    if (h >= 80) return 'No calibration actions needed';
    if (h >= 50) return 'Battery capacity is fading; plan a replacement';
    return 'Capacity is critically low; replace the battery';
  }

  String get timeRemainingLabel {
    final seconds = isCharging ? timeToFullSeconds : timeToEmptySeconds;
    if (seconds <= 0) return isCharging ? 'Charging' : 'Discharging';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return isCharging ? '${h}h ${m}m until full' : '${h}h ${m}m remaining';
  }

  @override
  List<Object?> get props => [
    percentage,
    state,
    healthPercent,
    cycleCount,
    temperatureCelsius,
    timeToEmptySeconds,
    timeToFullSeconds,
    energyFullWh,
    energyFullDesignWh,
    chargeThresholdSupported,
    chargeThresholdEnabled,
    chargeEndThreshold,
    chargeStartThreshold,
    model,
    vendor,
    activePowerProfile,
  ];

  BatterySnapshot copyWith({
    double? temperatureCelsius,
    String? activePowerProfile,
  }) {
    return BatterySnapshot(
      percentage: percentage,
      state: state,
      healthPercent: healthPercent,
      cycleCount: cycleCount,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      timeToEmptySeconds: timeToEmptySeconds,
      timeToFullSeconds: timeToFullSeconds,
      energyFullWh: energyFullWh,
      energyFullDesignWh: energyFullDesignWh,
      chargeThresholdSupported: chargeThresholdSupported,
      chargeThresholdEnabled: chargeThresholdEnabled,
      chargeEndThreshold: chargeEndThreshold,
      chargeStartThreshold: chargeStartThreshold,
      model: model,
      vendor: vendor,
      activePowerProfile: activePowerProfile ?? this.activePowerProfile,
    );
  }
}
