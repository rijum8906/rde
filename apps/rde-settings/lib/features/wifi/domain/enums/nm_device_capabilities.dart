class NmDeviceCapabilities {
  /// Device has no special capabilities
  static const int nmDeviceCapNone = 0x00000000;

  /// NetworkManager supports this device
  static const int nmDeviceCapNmSupported = 0x00000001;

  /// This device can indicate carrier status
  static const int nmDeviceCapCarrierDetect = 0x00000002;

  /// This device is a software device
  static const int nmDeviceCapIsSoftware = 0x00000004;

  /// This device supports single-root I/O virtualization
  static const int nmDeviceCapSriov = 0x00000008;
}
