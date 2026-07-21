import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

enum WifiStatus { initial, loading, success, failure }

class WifiState {
  final WifiStatus status;
  final bool isWifiEnabled;
  final List<WifiNetwork> networks;
  final String? connectedSsid;
  final String? connectingSsid;
  final String? errorMessage;

  const WifiState({
    required this.status,
    required this.isWifiEnabled,
    required this.networks,
    this.connectedSsid,
    this.connectingSsid,
    this.errorMessage,
  });

  factory WifiState.initial() {
    return const WifiState(
      status: WifiStatus.initial,
      isWifiEnabled: true,
      networks: [],
      connectedSsid: 'RDE-Net',
    );
  }

  WifiState copyWith({
    WifiStatus? status,
    bool? isWifiEnabled,
    List<WifiNetwork>? networks,
    String? connectedSsid,
    String? connectingSsid,
    String? errorMessage,
  }) {
    return WifiState(
      status: status ?? this.status,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      networks: networks ?? this.networks,
      connectedSsid: connectedSsid,
      connectingSsid: connectingSsid,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
