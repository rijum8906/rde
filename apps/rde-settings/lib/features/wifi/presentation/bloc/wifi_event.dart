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

/// Connects to [ssid], adding a NetworkManager profile when [password] is set.
///
/// When [promptOnFailure] is true and no password was supplied, a failed
/// attempt (for example an outdated saved profile) asks the page for a
/// password instead of only showing the error.
class ConnectToNetworkEvent extends WifiEvent {
  final String ssid;
  final String? password;
  final bool promptOnFailure;

  const ConnectToNetworkEvent(
    this.ssid, {
    this.password,
    this.promptOnFailure = false,
  });
}

/// Closes the password prompt without retrying the connection.
class DismissPasswordPromptEvent extends WifiEvent {
  const DismissPasswordPromptEvent();
}

class LoadSavedNetworksEvent extends WifiEvent {
  const LoadSavedNetworksEvent();
}

class ForgetSavedNetworkEvent extends WifiEvent {
  final String ssid;
  const ForgetSavedNetworkEvent(this.ssid);
}
