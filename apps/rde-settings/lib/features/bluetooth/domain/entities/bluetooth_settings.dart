class BluetoothSettings {
  final bool isEnabled;
  final bool isDiscoverable;

  const BluetoothSettings({
    required this.isEnabled,
    required this.isDiscoverable,
  });

  BluetoothSettings copyWith({bool? isEnabled, bool? isDiscoverable}) {
    return BluetoothSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
    );
  }
}
