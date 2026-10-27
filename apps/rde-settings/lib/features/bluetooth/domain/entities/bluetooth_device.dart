import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';

/// One Bluetooth device BlueZ knows about.
class BluetoothDevice {
  const BluetoothDevice({
    required this.path,
    required this.address,
    required this.name,
    required this.paired,
    required this.trusted,
    required this.connected,
    required this.servicesResolved,
    this.icon,
    this.rssi,
    this.batteryPercentage,
  });

  /// Object path of the device, such as
  /// `/org/bluez/hci0/dev_90_A0_BE_4B_BB_4F`.
  final String path;

  /// Device address, such as `90:A0:BE:4B:BB:4F`.
  final String address;

  /// Alias of the device, falling back to its advertised name.
  final String name;

  /// Whether the device is paired and has a bond with this controller.
  final bool paired;

  /// Whether the controller is allowed to connect without prompting.
  final bool trusted;

  /// Whether the device is connected right now.
  final bool connected;

  /// Whether the device's services have been discovered.
  final bool servicesResolved;

  /// Icon name BlueZ derived from the device's class, such as `audio-headset`.
  final String? icon;

  /// Signal strength reported during a scan, when the device advertises one.
  final int? rssi;

  /// Battery percentage of the device, when it publishes one.
  final int? batteryPercentage;

  /// Returns a copy with the given fields replaced.
  BluetoothDevice copyWith({
    bool? paired,
    bool? trusted,
    bool? connected,
    int? rssi,
  }) {
    return BluetoothDevice(
      path: path,
      address: address,
      name: name,
      paired: paired ?? this.paired,
      trusted: trusted ?? this.trusted,
      connected: connected ?? this.connected,
      servicesResolved: servicesResolved,
      icon: icon,
      rssi: rssi ?? this.rssi,
      batteryPercentage: batteryPercentage,
    );
  }
}

/// The adapter and the devices BlueZ reports in one read.
///
/// BlueZ publishes both through `org.freedesktop.DBus.ObjectManager`, so the
/// page reads them together instead of asking twice.
class BluetoothSnapshot {
  const BluetoothSnapshot({required this.adapter, required this.devices});

  /// The adapter the page manages, or `null` when the machine has no hardware.
  final BluetoothAdapter? adapter;

  /// Every device the adapter knows, connected, paired, or merely in range.
  final List<BluetoothDevice> devices;
}
