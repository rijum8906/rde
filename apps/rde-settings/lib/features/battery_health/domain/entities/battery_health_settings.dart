class BatteryHealthSettings {
  final int batteryLevel;
  final String status;
  final bool panelIndicator;

  const BatteryHealthSettings({
    required this.batteryLevel,
    required this.status,
    required this.panelIndicator,
  });

  BatteryHealthSettings copyWith({
    int? batteryLevel,
    String? status,
    bool? panelIndicator,
  }) {
    return BatteryHealthSettings(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      panelIndicator: panelIndicator ?? this.panelIndicator,
    );
  }
}
