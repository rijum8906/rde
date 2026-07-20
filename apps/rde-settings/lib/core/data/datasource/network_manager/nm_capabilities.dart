class NmCapabilities {
  /// Teams can be managed. This means the team device plugin is loaded.
  static const int team = 1;

  /// OpenVSwitch can be managed. This means the OVS device plugin is loaded. ( Since: nm version 1.24. )
  static const int ovs = 2;
}
