import 'package:equatable/equatable.dart';

abstract class BatteryHealthEvent extends Equatable {
  const BatteryHealthEvent();

  @override
  List<Object?> get props => [];
}

class BatteryHealthInitEvent extends BatteryHealthEvent {
  const BatteryHealthInitEvent();
}

/// Raised when UPower or power-profiles-daemon reports a change.
///
/// The event carries no payload: the bloc reads the authoritative state back
/// from the daemon when it handles the event.
class BatteryHealthServiceChangedEvent extends BatteryHealthEvent {
  const BatteryHealthServiceChangedEvent();
}

/// Asks the bloc to read the battery and the active profile again.
///
/// A burst of daemon signals is collapsed into this event once it settles, so
/// the read happens inside an event handler that can await it instead of from
/// the debounce timer, whose emitter has already completed.
class BatteryHealthRefreshEvent extends BatteryHealthEvent {
  const BatteryHealthRefreshEvent();
}

class TogglePowerSavingEvent extends BatteryHealthEvent {
  const TogglePowerSavingEvent(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class ToggleHealthProtectionEvent extends BatteryHealthEvent {
  const ToggleHealthProtectionEvent(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class ChangeChargeLimitEvent extends BatteryHealthEvent {
  const ChangeChargeLimitEvent(this.fraction);

  /// 0.6–1.0, matching the slider in the card.
  final double fraction;

  @override
  List<Object?> get props => [fraction];
}
