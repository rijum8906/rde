class DisplaySettings {
  final String resolution;
  final int refreshRate;
  final String layoutMode;
  final int nightLightTemp;

  const DisplaySettings({
    required this.resolution,
    required this.refreshRate,
    required this.layoutMode,
    required this.nightLightTemp,
  });

  DisplaySettings copyWith({
    String? resolution,
    int? refreshRate,
    String? layoutMode,
    int? nightLightTemp,
  }) {
    return DisplaySettings(
      resolution: resolution ?? this.resolution,
      refreshRate: refreshRate ?? this.refreshRate,
      layoutMode: layoutMode ?? this.layoutMode,
      nightLightTemp: nightLightTemp ?? this.nightLightTemp,
    );
  }
}
