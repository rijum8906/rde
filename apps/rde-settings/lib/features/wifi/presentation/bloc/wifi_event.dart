abstract class WifiEvent {
  const WifiEvent();
}

class WifiInitEvent extends WifiEvent {
  const WifiInitEvent();
}

class ScanNetworksEvent extends WifiEvent {
  const ScanNetworksEvent();
}

class ToggleWifiRadioEvent extends WifiEvent {
  final bool value;
  const ToggleWifiRadioEvent(this.value);
}

class ConnectToNetworkEvent extends WifiEvent {
  final String ssid;
  const ConnectToNetworkEvent(this.ssid);
}

class LoadSavedNetworksEvent extends WifiEvent {
  const LoadSavedNetworksEvent();
}

class ForgetSavedNetworkEvent extends WifiEvent {
  final String ssid;
  const ForgetSavedNetworkEvent(this.ssid);
}
