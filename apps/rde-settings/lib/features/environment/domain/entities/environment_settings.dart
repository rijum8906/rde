class EnvironmentSettings {
  final String hostname;
  final Map<String, String> envVariables;

  const EnvironmentSettings({
    required this.hostname,
    required this.envVariables,
  });

  EnvironmentSettings copyWith({
    String? hostname,
    Map<String, String>? envVariables,
  }) {
    return EnvironmentSettings(
      hostname: hostname ?? this.hostname,
      envVariables: envVariables ?? this.envVariables,
    );
  }
}
