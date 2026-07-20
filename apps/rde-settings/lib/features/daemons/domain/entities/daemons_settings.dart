class DaemonsSettings {
  final List<String> activeDaemons;

  const DaemonsSettings({required this.activeDaemons});

  DaemonsSettings copyWith({List<String>? activeDaemons}) {
    return DaemonsSettings(activeDaemons: activeDaemons ?? this.activeDaemons);
  }
}
