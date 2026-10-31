import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_adapter.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';

enum BluetoothStatus { initial, loading, success, failure }

class BluetoothState {
  /// Sentinel that distinguishes "keep the value" from "set it to null".
  static const Object _unset = Object();

  final BluetoothStatus status;

  /// Adapter the page manages, or `null` when the machine has no hardware.
  final BluetoothAdapter? adapter;

  /// Every device BlueZ knows, connected first.
  final List<BluetoothDevice> devices;

  /// Address of the device an operation is running on, if any.
  final String? busyAddress;

  final String? errorMessage;

  /// Message raised by an action the user asked for, shown as a notification.
  final String? noticeMessage;

  const BluetoothState({
    required this.status,
    required this.adapter,
    required this.devices,
    this.busyAddress,
    this.errorMessage,
    this.noticeMessage,
  });

  factory BluetoothState.initial() {
    return const BluetoothState(
      status: BluetoothStatus.initial,
      adapter: null,
      devices: [],
    );
  }

  /// Whether the machine has a Bluetooth adapter at all.
  bool get isAvailable => adapter != null;

  /// Whether the radio is on.
  bool get isEnabled => adapter?.powered ?? false;

  /// Whether the adapter is scanning for devices.
  bool get isDiscovering => adapter?.discovering ?? false;

  /// Whether the adapter advertises itself to other devices.
  bool get isDiscoverable => adapter?.discoverable ?? false;

  /// Devices connected right now.
  List<BluetoothDevice> get connectedDevices =>
      devices.where((device) => device.connected).toList();

  /// Every bonded device, connected or not.
  ///
  /// The paired page lists the whole bond list, because a paired device that
  /// is connected is still paired and should not vanish from it.
  List<BluetoothDevice> get pairedDevices =>
      devices.where((device) => device.paired).toList();

  /// Every device the daemon reports that is not connected right now.
  ///
  /// The connected devices are listed in their own column, so this list is the
  /// scan result: what the page can offer to connect to, without repeating the
  /// devices that are already in use.
  List<BluetoothDevice> get availableDevices =>
      devices.where((device) => !device.connected).toList();

  BluetoothState copyWith({
    BluetoothStatus? status,
    Object? adapter = _unset,
    List<BluetoothDevice>? devices,
    Object? busyAddress = _unset,
    Object? errorMessage = _unset,
    Object? noticeMessage = _unset,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      adapter: identical(adapter, _unset)
          ? this.adapter
          : adapter as BluetoothAdapter?,
      devices: devices ?? this.devices,
      busyAddress: identical(busyAddress, _unset)
          ? this.busyAddress
          : busyAddress as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      noticeMessage: identical(noticeMessage, _unset)
          ? this.noticeMessage
          : noticeMessage as String?,
    );
  }
}
