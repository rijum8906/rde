class SleepStatesSettings {
  final int dimDisplayDelay;
  final int suspendDelay;
  final int displayOffDelay;

  const SleepStatesSettings({
    required this.dimDisplayDelay,
    required this.suspendDelay,
    required this.displayOffDelay,
  });

  SleepStatesSettings copyWith({
    int? dimDisplayDelay,
    int? suspendDelay,
    int? displayOffDelay,
  }) {
    return SleepStatesSettings(
      dimDisplayDelay: dimDisplayDelay ?? this.dimDisplayDelay,
      suspendDelay: suspendDelay ?? this.suspendDelay,
      displayOffDelay: displayOffDelay ?? this.displayOffDelay,
    );
  }
}
