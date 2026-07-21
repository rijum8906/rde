class NmDeviceTypes {
  /// unknown device
  static const int unknown = 0;

  /// generic support for unrecognized device types
  static const int generic = 14;

  /// a wired ethernet device
  static const int ethernet = 1;

  /// an 802.11 Wi-Fi device
  static const int wifi = 2;

  /// not used
  static const int unused1 = 3;

  /// not used
  static const int unused2 = 4;

  /// a Bluetooth device supporting PAN or DUN access protocols
  static const int bluetooth = 5;

  /// an OLPC XO mesh networking device
  static const int olpcMesh = 6;

  /// an 802.16e Mobile WiMAX broadband device
  static const int wimax = 7;

  /// a modem supporting analog telephone, CDMA/EVDO, GSM/UMTS, or LTE network access protocols
  static const int modem = 8;

  /// an IP-over-InfiniBand device
  static const int infiniband = 9;

  /// a bond controller interface
  static const int bond = 10;

  /// an 802.1Q VLAN interface
  static const int vlan = 11;

  /// ADSL modem
  static const int adsl = 12;

  /// a bridge controller interface
  static const int bridge = 13;

  /// a team controller interface
  static const int team = 15;

  /// a TUN or TAP interface
  static const int tun = 16;

  /// a IP tunnel interface
  static const int ipTunnel = 17;

  /// a MACVLAN interface
  static const int macvlan = 18;

  /// a VXLAN interface
  static const int vxlan = 19;

  /// a VETH interface
  static const int veth = 20;

  /// a MACsec interface
  static const int macsec = 21;

  /// a dummy interface
  static const int dummy = 22;

  /// a PPP interface
  static const int ppp = 23;

  /// a Open vSwitch interface
  static const int ovsInterface = 24;

  /// a Open vSwitch port
  static const int ovsPort = 25;

  /// a Open vSwitch bridge
  static const int ovsBridge = 26;

  /// a IEEE 802.15.4 (WPAN) MAC Layer Device
  static const int wpan = 27;

  /// 6LoWPAN interface
  static const int lowpan = 28;

  /// a WireGuard interface
  static const int wireGuard = 29;

  /// an 802.11 Wi-Fi P2P device. Since: 1.16.
  static const int wifiP2p = 30;

  /// A VRF (Virtual Routing and Forwarding) interface. Since: 1.24.
  static const int vrf = 31;

  /// a loopback interface. Since: 1.42.
  static const int loopback = 32;

  /// A HSR/PRP device. Since: 1.46.
  static const int hsr = 33;

  /// A IPVLAN device. Since: 1.52.
  static const int ipvlan = 34;
}
