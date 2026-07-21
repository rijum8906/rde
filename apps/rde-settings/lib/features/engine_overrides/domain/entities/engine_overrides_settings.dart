class EngineOverridesSettings {
  final bool compositorEnabled;
  final String wmSwitcher;
  final double animationSpeed;

  const EngineOverridesSettings({
    required this.compositorEnabled,
    required this.wmSwitcher,
    required this.animationSpeed,
  });

  EngineOverridesSettings copyWith({
    bool? compositorEnabled,
    String? wmSwitcher,
    double? animationSpeed,
  }) {
    return EngineOverridesSettings(
      compositorEnabled: compositorEnabled ?? this.compositorEnabled,
      wmSwitcher: wmSwitcher ?? this.wmSwitcher,
      animationSpeed: animationSpeed ?? this.animationSpeed,
    );
  }
}
