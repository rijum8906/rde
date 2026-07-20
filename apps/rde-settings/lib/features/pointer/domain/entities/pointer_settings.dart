class PointerSettings {
  final double mouseSpeed;
  final bool acceleration;
  final bool naturalScroll;

  const PointerSettings({
    required this.mouseSpeed,
    required this.acceleration,
    required this.naturalScroll,
  });

  PointerSettings copyWith({
    double? mouseSpeed,
    bool? acceleration,
    bool? naturalScroll,
  }) {
    return PointerSettings(
      mouseSpeed: mouseSpeed ?? this.mouseSpeed,
      acceleration: acceleration ?? this.acceleration,
      naturalScroll: naturalScroll ?? this.naturalScroll,
    );
  }
}
