class DashboardSettings {
  final bool isDarkMode;
  final bool isWifiEnabled;
  final bool isBluetoothEnabled;
  final bool isDndEnabled;
  final double batteryLevel;
  final double ramUsage;
  final double storageUsage;

  const DashboardSettings({
    required this.isDarkMode,
    required this.isWifiEnabled,
    required this.isBluetoothEnabled,
    required this.isDndEnabled,
    required this.batteryLevel,
    required this.ramUsage,
    required this.storageUsage,
  });

  DashboardSettings copyWith({
    bool? isDarkMode,
    bool? isWifiEnabled,
    bool? isBluetoothEnabled,
    bool? isDndEnabled,
    double? batteryLevel,
    double? ramUsage,
    double? storageUsage,
  }) {
    return DashboardSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      isDndEnabled: isDndEnabled ?? this.isDndEnabled,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      ramUsage: ramUsage ?? this.ramUsage,
      storageUsage: storageUsage ?? this.storageUsage,
    );
  }
}
