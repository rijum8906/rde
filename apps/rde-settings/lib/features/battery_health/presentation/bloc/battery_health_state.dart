class BatteryHealthState {
  final bool powerSavingMode;
  final bool healthProtection;
  final double chargeLimit;

  const BatteryHealthState({
    required this.powerSavingMode,
    required this.healthProtection,
    required this.chargeLimit,
  });

  factory BatteryHealthState.initial() {
    return const BatteryHealthState(
      powerSavingMode: false,
      healthProtection: true,
      chargeLimit: 0.8,
    );
  }

  BatteryHealthState copyWith({
    bool? powerSavingMode,
    bool? healthProtection,
    double? chargeLimit,
  }) {
    return BatteryHealthState(
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      healthProtection: healthProtection ?? this.healthProtection,
      chargeLimit: chargeLimit ?? this.chargeLimit,
    );
  }
}
