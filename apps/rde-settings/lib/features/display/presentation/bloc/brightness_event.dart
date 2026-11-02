abstract class BrightnessEvent {
  const BrightnessEvent();
}

/// Reads the brightness the service reports.
class BrightnessInitEvent extends BrightnessEvent {
  const BrightnessInitEvent();
}

/// The slider moved to [percent]; the write is committed once it settles.
class BrightnessSliderChangedEvent extends BrightnessEvent {
  final int percent;

  const BrightnessSliderChangedEvent(this.percent);
}

/// Writes [percent] to the service now, without waiting for a drag to settle.
class BrightnessSetEvent extends BrightnessEvent {
  final int percent;

  const BrightnessSetEvent(this.percent);
}

/// Raises the active display by [step] percentage points.
class BrightnessIncreaseEvent extends BrightnessEvent {
  final int step;

  const BrightnessIncreaseEvent(this.step);
}

/// Lowers the active display by [step] percentage points.
class BrightnessDecreaseEvent extends BrightnessEvent {
  final int step;

  const BrightnessDecreaseEvent(this.step);
}

/// The service reported a brightness change another client made.
class BrightnessServiceChangedEvent extends BrightnessEvent {
  const BrightnessServiceChangedEvent();
}
