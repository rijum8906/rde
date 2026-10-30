/// Device state change reason codes for NetworkManager.
///
/// These values indicate why a device's state changed.
/// Only WiFi-relevant reasons are included here.
///
/// Based on NetworkManager's NM_DEVICE_STATE_REASON_* constants.
class NMDeviceStateReason {
  // ============================================
  // ESSENTIAL REASONS
  // ============================================

  /// No reason given (0)
  ///
  /// The state change happened without any specific reason.
  /// This is the default/initial state.
  ///
  /// Example: Device connected successfully, no error occurred.
  static const int none = 0;

  /// The device could not be readied for configuration (4)
  ///
  /// The device failed to prepare for connection.
  /// This could happen due to:
  /// - Hardware initialization failure
  /// - Driver issues
  /// - Resource conflicts
  ///
  /// User action: Check system logs, restart NetworkManager.
  static const int configFailed = 4;

  /// Secrets were required, but not provided (7)
  ///
  /// The network requires a password/key but none was provided.
  /// This is the most common WiFi connection error.
  ///
  /// Common scenarios:
  /// - Wrong WiFi password entered
  /// - Password field left empty
  /// - Saved password is incorrect
  /// - WPA Enterprise credentials missing
  ///
  /// User action: Re-enter the correct password.
  static const int noSecrets = 7;

  /// Device disconnected by user or client (39)
  ///
  /// The disconnection was initiated by the user or application.
  /// This is a normal, expected disconnection.
  ///
  /// Examples:
  /// - User clicked "Disconnect" in settings
  /// - User turned off WiFi toggle
  /// - Application requested disconnection
  ///
  /// User action: Connect to a network to re-establish connection.
  static const int userRequested = 39;

  /// Carrier/link changed (40)
  ///
  /// The physical link state changed.
  /// Usually indicates a hardware issue.
  ///
  /// Common causes:
  /// - WiFi hardware switch is turned off
  /// - Airplane mode is enabled
  /// - WiFi adapter disconnected
  /// - Hardware failure
  ///
  /// User action: Check WiFi switch/hardware, disable airplane mode.
  static const int carrier = 40;

  /// The Wi-Fi network could not be found (53)
  ///
  /// The requested SSID is not in range or not broadcasting.
  ///
  /// Common scenarios:
  /// - Network is out of range
  /// - Network is down/hidden
  /// - Wrong network name entered
  /// - Router is powered off
  /// - Network is not broadcasting SSID
  ///
  /// User action: Move closer to the router, verify network name.
  static const int ssidNotFound = 53;

  // ============================================
  // OPTIONAL REASONS (Useful for better error handling)
  // ============================================

  /// IP configuration could not be reserved (5)
  ///
  /// DHCP failed to get an IP address for the device.
  ///
  /// Common causes:
  /// - DHCP server not responding
  /// - No available IP addresses in DHCP pool
  /// - Network congestion or timeout
  /// - Router issues
  ///
  /// User action: Try reconnecting, check router DHCP settings.
  static const int ipConfigUnavailable = 5;

  /// 802.1x supplicant failed (10)
  ///
  /// Authentication failed at the 802.1x level.
  ///
  /// Common scenarios:
  /// - Enterprise WiFi (WPA2-Enterprise) authentication failed
  /// - Invalid username/password
  /// - Certificate validation failed
  /// - RADIUS server unavailable
  ///
  /// User action: Check enterprise credentials, ensure certificates are valid.
  static const int supplicantFailed = 10;

  /// 802.1x supplicant took too long to authenticate (11)
  ///
  /// Authentication process timed out.
  ///
  /// Common causes:
  /// - Slow authentication server
  /// - Network congestion
  /// - Wrong authentication method
  /// - Certificate mismatch
  ///
  /// User action: Try again, check authentication settings.
  static const int supplicantTimeout = 11;

  /// Necessary firmware for the device may be missing (35)
  ///
  /// The WiFi adapter requires firmware that is not installed.
  ///
  /// Common on:
  /// - Broadcom WiFi adapters (b43)
  /// - Realtek WiFi adapters
  /// - Some Intel WiFi adapters
  ///
  /// User action: Install required firmware packages.
  static const int firmwareMissing = 35;

  /// The device was removed (36)
  ///
  /// The WiFi device was physically removed or unplugged.
  ///
  /// Common scenarios:
  /// - USB WiFi adapter unplugged
  /// - PCMCIA/Cardbus card ejected
  /// - Internal WiFi card disabled in BIOS
  /// - Thunderbolt/USB-C dock disconnected
  ///
  /// User action: Reconnect the device, restart if internal.
  static const int removed = 36;

  /// NetworkManager went to sleep (37)
  ///
  /// The system entered sleep/suspend state.
  ///
  /// Example: Laptop lid closed, system suspended.
  ///
  /// User action: Wake the system, WiFi will reconnect automatically.
  static const int sleeping = 37;

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get a user-friendly error message for the reason code.
  ///
  /// Example:
  /// ```dart
  /// final msg = NMDeviceStateReason.getMessage(7);
  /// // Returns: "Password required or incorrect"
  /// ```
  static String getMessage(int reason) {
    switch (reason) {
      // Essential reasons
      case none:
        return '';
      case configFailed:
        return 'Connection configuration failed. Please try again.';
      case noSecrets:
        return 'Password required or incorrect. Please re-enter the password.';
      case userRequested:
        return 'Disconnected by user.';
      case carrier:
        return 'WiFi hardware is not available. Please check your WiFi switch.';
      case ssidNotFound:
        return 'Network not found. Please check the network name and try again.';

      // Optional reasons
      case ipConfigUnavailable:
        return 'Failed to obtain IP address. Please try reconnecting.';
      case supplicantFailed:
        return 'Authentication failed. Please check your credentials.';
      case supplicantTimeout:
        return 'Authentication timed out. Please try again.';
      case firmwareMissing:
        return 'Driver or firmware missing. Please install required firmware.';
      case removed:
        return 'WiFi device was removed. Please reconnect it.';
      case sleeping:
        return 'System is sleeping. WiFi will reconnect when system wakes.';

      default:
        return 'Connection failed (Reason: $reason).';
    }
  }

  /// Get a short label for the reason code.
  ///
  /// Example:
  /// ```dart
  /// final label = NMDeviceStateReason.getLabel(7);
  /// // Returns: "Password required"
  /// ```
  static String getLabel(int reason) {
    switch (reason) {
      case none:
        return 'No error';
      case configFailed:
        return 'Configuration failed';
      case noSecrets:
        return 'Password required';
      case userRequested:
        return 'Disconnected by user';
      case carrier:
        return 'Hardware unavailable';
      case ssidNotFound:
        return 'Network not found';
      case ipConfigUnavailable:
        return 'IP address unavailable';
      case supplicantFailed:
        return 'Authentication failed';
      case supplicantTimeout:
        return 'Authentication timeout';
      case firmwareMissing:
        return 'Firmware missing';
      case removed:
        return 'Device removed';
      case sleeping:
        return 'System sleeping';
      default:
        return 'Unknown reason';
    }
  }

  /// Check if the reason indicates a user action.
  ///
  /// Example:
  /// ```dart
  /// final isUser = NMDeviceStateReason.isUserAction(39);
  /// // Returns: true
  /// ```
  static bool isUserAction(int reason) => reason == userRequested;

  /// Check if the reason indicates a recoverable error.
  ///
  /// These errors can be fixed by the user retrying.
  ///
  /// Example: Wrong password (noSecrets), timeout (supplicantTimeout)
  static bool isRecoverable(int reason) =>
      reason == noSecrets ||
      reason == supplicantTimeout ||
      reason == ipConfigUnavailable;

  /// Check if the reason indicates a hardware/driver issue.
  ///
  /// These require physical or system-level changes.
  ///
  /// Example: WiFi switch off (carrier), firmware missing (firmwareMissing)
  static bool isHardwareIssue(int reason) =>
      reason == carrier || reason == firmwareMissing || reason == removed;

  /// Check if the reason indicates a network availability issue.
  ///
  /// Example: Network not found (ssidNotFound), DHCP issue (ipConfigUnavailable)
  static bool isNetworkIssue(int reason) =>
      reason == ssidNotFound || reason == ipConfigUnavailable;

  /// Check if the reason requires user attention (not automatic).
  ///
  /// Example: Wrong password (noSecrets), authentication failed (supplicantFailed)
  static bool requiresUserAttention(int reason) =>
      reason == noSecrets ||
      reason == supplicantFailed ||
      reason == supplicantTimeout ||
      reason == configFailed;

  /// Check if the reason is a normal/expected state change.
  ///
  /// Example: User disconnected (userRequested), sleeping (sleeping)
  static bool isNormal(int reason) =>
      reason == none || reason == userRequested || reason == sleeping;

  /// Check if the reason indicates a critical failure.
  ///
  /// Example: Configuration failed (configFailed), firmware missing (firmwareMissing)
  static bool isCritical(int reason) =>
      reason == configFailed || reason == firmwareMissing || reason == removed;
}
