class Nm80211ApFlags {
  /// access point has no special capabilities
  static const int none = 0;

  /// access point requires authentication and encryption (usually means WEP)
  static const int privacy = 1;

  /// access point supports some WPS method
  static const int wps = 2;

  /// access point supports push-button WPS
  static const int wpsPbc = 4;

  /// access point supports PIN-based WPS
  static const int wpsPin = 8;
}

class Nm80211ApSecurityFlags {
  /// the access point has no special security requirements
  static const int none = 0;

  /// 40/64-bit WEP is supported for pairwise/unicast encryption
  static const int pairWep40 = 1;

  ///104/128-bit WEP is supported for pairwise/unicast encryption
  static const int pairWep104 = 2;

  /// TKIP is supported for pairwise/unicast encryption
  static const int pairTkip = 4;

  /// AES/CCMP is supported for pairwise/unicast encryption
  static const int pairCcmp = 8;

  /// 40/64-bit WEP is supported for group/broadcast encryption
  static const int groupWep40 = 10;

  /// 104/128-bit WEP is supported for group/broadcast encryption
  static const int groupWep104 = 20;

  /// TKIP is supported for group/broadcast encryption
  static const int groupTkip = 40;

  /// AES/CCMP is supported for group/broadcast encryption
  static const int groupCcmp = 80;

  /// WPA/RSN Pre-Shared Key encryption is supported
  static const int mgmtPsk = 100;

  /// 802.1x authentication and key management is supported
  static const int mgmt8021x = 200;

  /// WPA/RSN Simultaneous Authentication of Equals is supported
  static const int mgmtSae = 400;

  /// WPA/RSN Opportunistic Wireless Encryption is supported
  static const int mgmtOwe = 800;

  /// WPA/RSN Opportunistic Wireless Encryption transition mode is supported. Since: 1.26.
  static const int mgmtOweTransition = 1000;

  /// WPA3 Enterprise Suite-B 192 bit mode is supported. Since: 1.30.
  static const int mgmtEapSuiteB192 = 2000;
}

/// 802.11 operation modes for WiFi devices and access points
///
/// These constants define the possible operation modes for:
/// - WiFi devices (NetworkManager Device)
/// - Access Points (NetworkManager AccessPoint)
///
/// Based on NetworkManager's NM_802_11_MODE_* constants
class NM80211Mode {
  /// The device or access point mode is unknown.
  ///
  /// This typically indicates the mode could not be determined
  /// or the device/AP hasn't reported its mode yet.
  static const int unknown = 0;

  /// Ad-Hoc (Independent Basic Service Set) mode.
  ///
  /// For both devices and access point objects, indicates the object
  /// is part of an Ad-Hoc 802.11 network without a central coordinating
  /// access point.
  ///
  /// In Ad-Hoc mode:
  /// - Devices communicate directly with each other (peer-to-peer)
  /// - No central access point is required
  /// - Also known as IBSS (Independent Basic Service Set)
  /// - Range is typically limited compared to infrastructure mode
  /// - Each device manages its own beaconing
  ///
  /// Use cases:
  /// - Temporary network setups
  /// - File sharing between devices
  /// - Gaming between nearby devices
  /// - Situations where no infrastructure exists
  static const int adhoc = 1;

  /// Infrastructure mode (Managed/Client mode).
  ///
  /// The device or access point is in infrastructure mode.
  ///
  /// For devices (clients):
  /// - Indicates the device is an 802.11 client/station (STA)
  /// - Device connects to an access point (AP)
  /// - Most common mode for laptops, phones, and tablets
  /// - Device scans for and connects to available APs
  /// - All traffic goes through the AP
  ///
  /// For access point objects:
  /// - Indicates the object is an access point that provides
  ///   connectivity to clients
  /// - Central hub for all network traffic
  /// - Manages authentication and encryption
  /// - Handles DHCP and routing
  ///
  /// Use cases:
  /// - Home WiFi networks
  /// - Office networks
  /// - Public hotspots
  /// - Most standard WiFi connections
  static const int infra = 2;

  /// Access Point (Hotspot) mode.
  ///
  /// The device is an access point/hotspot.
  ///
  /// Important notes:
  /// - NOT valid for access point objects (AccessPoint interface)
  /// - Used only for hotspot mode on the local machine
  /// - Device acts as an AP for other devices to connect to
  /// - Requires the device to support AP mode
  /// - Can share internet connection with connected clients
  /// - Often used with NetworkManager's hotspot feature
  ///
  /// Capabilities:
  /// - Hosts its own SSID
  /// - Manages client connections
  /// - Provides IP addresses (DHCP server)
  /// - Can perform NAT/Internet sharing
  /// - Supports encryption (WPA2/WPA3)
  ///
  /// Use cases:
  /// - Mobile hotspot (sharing cellular data)
  /// - Creating a temporary network
  /// - IoT device setup
  /// - Testing and development
  static const int ap = 3;

  /// Mesh (802.11s) mode.
  ///
  /// The device is a 802.11s mesh point.
  ///
  /// 802.11s is a standard for wireless mesh networking where:
  /// - Multiple devices form a self-organizing network
  /// - Each device relays data for others (multi-hop)
  /// - No central AP required
  /// - Self-healing (routes adjust when nodes fail)
  /// - Auto-discovery of neighbors
  ///
  /// Mesh mode features:
  /// - Multi-hop communication
  /// - Self-forming network
  /// - Self-healing routing
  /// - Automatic topology discovery
  /// - Peer-to-peer data forwarding
  /// - Dynamic path selection
  ///
  /// Common in:
  /// - IoT networks
  /// - Smart home devices
  /// - Sensor networks
  /// - Community networks
  /// - Disaster recovery networks
  ///
  /// Since: NetworkManager 1.20
  static const int mesh = 4;

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Convert a mode integer to its string representation
  static String getName(int mode) {
    switch (mode) {
      case unknown:
        return 'Unknown';
      case adhoc:
        return 'Ad-Hoc';
      case infra:
        return 'Infrastructure';
      case ap:
        return 'Access Point';
      case mesh:
        return 'Mesh';
      default:
        return 'Unknown ($mode)';
    }
  }

  /// Check if the mode is a valid/known mode
  static bool isValid(int mode) {
    return mode >= unknown && mode <= mesh;
  }

  /// Check if the mode is infrastructure (client) mode
  static bool isInfrastructure(int mode) => mode == infra;

  /// Check if the mode is access point (hotspot) mode
  static bool isAccessPoint(int mode) => mode == ap;

  /// Check if the mode is mesh mode
  static bool isMesh(int mode) => mode == mesh;

  /// Check if the mode is ad-hoc mode
  static bool isAdhoc(int mode) => mode == adhoc;

  /// Check if the mode is suitable for connecting to existing networks
  static bool isClientMode(int mode) {
    return mode == infra || mode == adhoc;
  }

  /// Check if the mode allows acting as a network provider
  static bool isServerMode(int mode) {
    return mode == ap || mode == mesh;
  }
}
