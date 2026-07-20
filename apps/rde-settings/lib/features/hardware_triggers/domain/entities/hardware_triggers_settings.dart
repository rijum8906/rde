class HardwareTriggersSettings {
  final String lidCloseAction;
  final String powerButtonAction;
  final String lowBatteryAction;

  const HardwareTriggersSettings({
    required this.lidCloseAction,
    required this.powerButtonAction,
    required this.lowBatteryAction,
  });

  HardwareTriggersSettings copyWith({
    String? lidCloseAction,
    String? powerButtonAction,
    String? lowBatteryAction,
  }) {
    return HardwareTriggersSettings(
      lidCloseAction: lidCloseAction ?? this.lidCloseAction,
      powerButtonAction: powerButtonAction ?? this.powerButtonAction,
      lowBatteryAction: lowBatteryAction ?? this.lowBatteryAction,
    );
  }
}
