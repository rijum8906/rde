/// WiFi device properties from NetworkManager.
/// Only the properties actually needed for a WiFi settings app.
class NMDevice {
  /// Device interface name (e.g., "wlan0")
  final String interface;

  /// MAC address of the device
  final String hwAddress;

  /// Driver name (e.g., "iwlwifi" for Intel)
  final String driver;

  /// Firmware version
  final String firmwareVersion;

  /// Current device state (see NMDeviceState)
  final int state;

  /// Reason for state change (see NMDeviceStateReason)
  final int stateReason;

  /// Device type (2 = WiFi)
  final int deviceType;

  /// Whether NetworkManager manages this device
  final bool managed;

  /// Whether auto-connect is enabled
  final bool autoconnect;

  /// MTU size
  final int mtu;

  /// Path to the active connection (null if not connected)
  final String? activeConnection;

  const NMDevice({
    required this.interface,
    required this.hwAddress,
    required this.driver,
    required this.firmwareVersion,
    required this.state,
    required this.stateReason,
    required this.deviceType,
    required this.managed,
    required this.autoconnect,
    required this.mtu,
    this.activeConnection,
  });

  /// True if this is a WiFi device
  bool get isWiFi => deviceType == 2;

  /// True if connected (state = 100)
  bool get isConnected => state == 100;

  /// True if disconnected (state = 30)
  bool get isDisconnected => state == 30;

  /// True if connecting (state between 40-90)
  bool get isConnecting => state >= 40 && state <= 90;
}
