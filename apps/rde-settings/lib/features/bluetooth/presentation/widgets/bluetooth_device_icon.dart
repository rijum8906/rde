import 'package:flutter/material.dart';
import 'package:rde_settings/features/bluetooth/presentation/utils/bluetooth_device_helpers.dart';

/// Renders the Material icon that corresponds to a BlueZ device class.
class BluetoothDeviceIcon extends StatelessWidget {
  const BluetoothDeviceIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 20,
  });

  final String? icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(iconForBluetoothClass(icon), size: size, color: color);
  }
}
