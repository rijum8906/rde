class KeyboardSettings {
  final String layout;
  final int repeatDelay;
  final int repeatRate;
  final bool bootNumLock;

  const KeyboardSettings({
    required this.layout,
    required this.repeatDelay,
    required this.repeatRate,
    required this.bootNumLock,
  });

  KeyboardSettings copyWith({
    String? layout,
    int? repeatDelay,
    int? repeatRate,
    bool? bootNumLock,
  }) {
    return KeyboardSettings(
      layout: layout ?? this.layout,
      repeatDelay: repeatDelay ?? this.repeatDelay,
      repeatRate: repeatRate ?? this.repeatRate,
      bootNumLock: bootNumLock ?? this.bootNumLock,
    );
  }
}
