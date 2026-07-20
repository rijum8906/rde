class WmBindingsSettings {
  final List<String> keybindings;

  const WmBindingsSettings({required this.keybindings});

  WmBindingsSettings copyWith({List<String>? keybindings}) {
    return WmBindingsSettings(keybindings: keybindings ?? this.keybindings);
  }
}
