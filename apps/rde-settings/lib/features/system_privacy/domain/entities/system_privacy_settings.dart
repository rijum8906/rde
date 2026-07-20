class SystemPrivacySettings {
  final bool clipboardHistory;
  final bool recentLogs;
  final bool telemetry;

  const SystemPrivacySettings({
    required this.clipboardHistory,
    required this.recentLogs,
    required this.telemetry,
  });

  SystemPrivacySettings copyWith({
    bool? clipboardHistory,
    bool? recentLogs,
    bool? telemetry,
  }) {
    return SystemPrivacySettings(
      clipboardHistory: clipboardHistory ?? this.clipboardHistory,
      recentLogs: recentLogs ?? this.recentLogs,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
