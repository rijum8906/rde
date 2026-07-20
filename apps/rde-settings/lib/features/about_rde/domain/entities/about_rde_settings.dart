class AboutRdeSettings {
  final String osVersion;
  final String architecture;
  final bool autoUpdates;

  const AboutRdeSettings({
    required this.osVersion,
    required this.architecture,
    required this.autoUpdates,
  });

  AboutRdeSettings copyWith({
    String? osVersion,
    String? architecture,
    bool? autoUpdates,
  }) {
    return AboutRdeSettings(
      osVersion: osVersion ?? this.osVersion,
      architecture: architecture ?? this.architecture,
      autoUpdates: autoUpdates ?? this.autoUpdates,
    );
  }
}
