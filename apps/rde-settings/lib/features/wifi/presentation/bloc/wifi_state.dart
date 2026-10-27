import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

enum WifiStatus { initial, loading, success, failure }

class WifiState {
  /// Sentinel that distinguishes "keep the value" from "set it to null".
  static const Object _unset = Object();

  final WifiStatus status;
  final bool isWifiEnabled;
  final List<WifiNetwork> networks;
  final List<WifiNetwork> savedNetworks;
  final String? connectedSsid;
  final String? connectingSsid;
  final String? errorMessage;

  /// Network whose saved-profile connection failed and that needs a password.
  final String? passwordPromptSsid;

  /// Network the user just connected to through this page.
  ///
  /// Only an explicit connect sets it, so opening the page on an already
  /// connected network, or seeing a live NetworkManager update, shows no
  /// notification. Every read of the daemon state clears it again.
  final String? connectedNoticeSsid;

  const WifiState({
    required this.status,
    required this.isWifiEnabled,
    required this.networks,
    required this.savedNetworks,
    this.connectedSsid,
    this.connectingSsid,
    this.errorMessage,
    this.passwordPromptSsid,
    this.connectedNoticeSsid,
  });

  factory WifiState.initial() {
    return const WifiState(
      status: WifiStatus.initial,
      isWifiEnabled: true,
      networks: [],
      savedNetworks: [],
    );
  }

  WifiState copyWith({
    WifiStatus? status,
    bool? isWifiEnabled,
    List<WifiNetwork>? networks,
    List<WifiNetwork>? savedNetworks,
    Object? connectedSsid = _unset,
    Object? connectingSsid = _unset,
    Object? errorMessage = _unset,
    Object? passwordPromptSsid = _unset,
    Object? connectedNoticeSsid = _unset,
  }) {
    return WifiState(
      status: status ?? this.status,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      networks: networks ?? this.networks,
      savedNetworks: savedNetworks ?? this.savedNetworks,
      connectedSsid: identical(connectedSsid, _unset)
          ? this.connectedSsid
          : connectedSsid as String?,
      connectingSsid: identical(connectingSsid, _unset)
          ? this.connectingSsid
          : connectingSsid as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      passwordPromptSsid: identical(passwordPromptSsid, _unset)
          ? this.passwordPromptSsid
          : passwordPromptSsid as String?,
      connectedNoticeSsid: identical(connectedNoticeSsid, _unset)
          ? this.connectedNoticeSsid
          : connectedNoticeSsid as String?,
    );
  }
}
