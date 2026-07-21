abstract class BatteryHealthEvent {
  const BatteryHealthEvent();
}

class TogglePowerSavingEvent extends BatteryHealthEvent {
  final bool value;
  const TogglePowerSavingEvent(this.value);
}

class ToggleHealthProtectionEvent extends BatteryHealthEvent {
  final bool value;
  const ToggleHealthProtectionEvent(this.value);
}

class ChangeChargeLimitEvent extends BatteryHealthEvent {
  final double value;
  const ChangeChargeLimitEvent(this.value);
}
