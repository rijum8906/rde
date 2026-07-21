abstract class AboutRdeEvent {
  const AboutRdeEvent();
}

class TriggerUpdateCheckEvent extends AboutRdeEvent {
  const TriggerUpdateCheckEvent();
}

class RotateLogoEvent extends AboutRdeEvent {
  final double amount;
  const RotateLogoEvent(this.amount);
}

class ResetUpdateStatusEvent extends AboutRdeEvent {
  const ResetUpdateStatusEvent();
}
