/// NMState values indicate the current overall networking state.
class NmStates {
  /// Networking state is unknown. This indicates a daemon error that makes it unable to reasonably assess the state.
  /// In such event the applications are expected to assume Internet connectivity might be present and not disable controls that require network access.
  static const int unknown = 0;

  /// NetworkManager is disabled, either because the user requested to disable networking or because the system is suspended or resuming from suspend.
  static const int disabled = 10;

  /// There is no active network connection.
  static const int disconnected = 20;

  /// Network connections are being cleaned up. The applications should tear down their network sessions.
  static const int disconnecting = 30;

  /// A network connection is being started
  static const int connecting = 40;

  /// There is only local IPv4 and/or IPv6 connectivity, but no default route to access the Internet.
  static const int connectedLocal = 50;

  /// There is only site-wide IPv4 and/or IPv6 connectivity. This means a default route is available,
  /// but the Internet connectivity check (see "Connectivity" property) did not succeed.
  //// The graphical shell should indicate limited network connectivity.
  static const int connectedSite = 60;

  /// There is global IPv4 and/or IPv6 Internet connectivity This means the Internet connectivity check succeeded,
  static const int connectedGlobal = 70;
}

/// Only the states you actually need to care about
class NmDeviceStates {
  static const int unknown = 0;
  static const int unavailable = 20;
  static const int disconnected = 30;
  static const int connectingStart = 40; // PREPARE
  static const int connectingEnd = 90; // SECONDARIES
  static const int connected = 100;
  static const int failed = 120;

  /// Convert NM state to simple UI state
  static String toUIState(int state) {
    if (state == disconnected) return 'Disconnected';
    if (state == connected) return 'Connected';
    if (state == failed) return 'Failed';
    if (state == unavailable) return 'Unavailable';
    if (state >= connectingStart && state <= connectingEnd) {
      return 'Connecting...';
    }
    return 'Unknown';
  }

  /// Check if device is connected
  static bool isConnected(int state) => state == connected;

  /// Check if device is connecting
  static bool isConnecting(int state) =>
      state >= connectingStart && state <= connectingEnd;

  /// Check if device is disconnected
  static bool isDisconnected(int state) =>
      state == disconnected || state == unknown || state == unavailable;

  /// Check if device is in a usable state
  static bool isUsable(int state) =>
      state == disconnected ||
      state == connected ||
      (state >= connectingStart && state <= connectingEnd);
}

class NmConnectivityStates {
  /// Network connectivity is unknown. This means the connectivity checks are disabled (e.g. on server installations) or has not run yet
  static const int unknown = 0;

  /// The host is not connected to any network.
  /// The graphical shell should use this state to indicate the network connection is unavailable.
  // NOTE: There's no active connection that contains a default route to the internet and thus it makes no sense to even attempt a connectivity check.
  static const int none = 1;

  /// The Internet connection is hijacked by a captive portal gateway.
  /// The graphical shell may open a sandboxed web browser window (because the captive portals typically attempt a man-in-the-middle attacks against the https connections)
  /// for the purpose of authenticating to a gateway and retrigger the connectivity check with CheckConnectivity() when the browser window is dismissed.
  static const int portal = 2;

  /// The host is connected to a network, does not appear to be able to reach the full Internet, but a captive portal has not been detected.
  static const int limited = 3;

  /// The host is connected to a network, and appears to be able to reach the full Internet.
  static const int full = 4;
}

/// Active connection states for WiFi connections.
///
/// These indicate the state of the current WiFi connection.
/// Only states relevant to WiFi connections are included.
class NMActiveConnectionState {
  /// The connection is being established (1)
  ///
  /// Example: WiFi is connecting to the network.
  /// Show: "Connecting..." spinner
  static const int activating = 1;

  /// The connection is active and working (2)
  ///
  /// Example: WiFi is connected and working.
  /// Show: "Connected" ✅
  static const int activated = 2;

  /// The connection is being disconnected (3)
  ///
  /// Example: WiFi is disconnecting.
  /// Show: "Disconnecting..."
  static const int deactivating = 3;

  /// Convert state to a user-friendly label.
  ///
  /// Example:
  /// ```dart
  /// final label = NMActiveConnectionState.getLabel(2);
  /// // Returns: "Connected"
  /// ```
  static String getLabel(int state) {
    switch (state) {
      case activating:
        return 'Connecting...';
      case activated:
        return 'Connected';
      case deactivating:
        return 'Disconnecting...';
      default:
        return 'Disconnected';
    }
  }

  /// Check if the connection is active.
  static bool isActive(int state) => state == activated;

  /// Check if the connection is in progress.
  static bool isInProgress(int state) =>
      state == activating || state == deactivating;
}
