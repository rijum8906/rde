/// State of one Bluetooth adapter as BlueZ reports it.
class BluetoothAdapter {
  const BluetoothAdapter({
    required this.path,
    required this.address,
    required this.name,
    required this.powered,
    required this.discoverable,
    required this.discovering,
  });

  /// Object path of the adapter, such as `/org/bluez/hci0`.
  final String path;

  /// Controller address, such as `14:B5:CD:3D:42:04`.
  final String address;

  /// Alias the user or the system gave the controller.
  final String name;

  /// Whether the radio is on.
  final bool powered;

  /// Whether the controller advertises itself to other devices.
  final bool discoverable;

  /// Whether the controller is scanning for devices right now.
  final bool discovering;

  /// Returns a copy with the given fields replaced.
  BluetoothAdapter copyWith({
    bool? powered,
    bool? discoverable,
    bool? discovering,
  }) {
    return BluetoothAdapter(
      path: path,
      address: address,
      name: name,
      powered: powered ?? this.powered,
      discoverable: discoverable ?? this.discoverable,
      discovering: discovering ?? this.discovering,
    );
  }
}
