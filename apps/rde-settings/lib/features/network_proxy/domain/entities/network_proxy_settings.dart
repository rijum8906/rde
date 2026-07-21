class NetworkProxySettings {
  final bool isEnabled;
  final String type;
  final String host;
  final int port;

  const NetworkProxySettings({
    required this.isEnabled,
    required this.type,
    required this.host,
    required this.port,
  });

  NetworkProxySettings copyWith({
    bool? isEnabled,
    String? type,
    String? host,
    int? port,
  }) {
    return NetworkProxySettings(
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}
