import 'package:flutter/material.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';

/// One-line summary under a device's name: address, battery, signal, flags.
String subtitleForDevice(BluetoothDevice device) {
  final parts = <String>[
    device.address,
    if (device.batteryPercentage != null) '${device.batteryPercentage}%',
    if (device.rssi != null) '${device.rssi} dBm',
    if (device.paired) 'Paired',
    if (device.trusted) 'Trusted',
  ];
  return parts.join(' • ');
}

/// Maps the icon name BlueZ derives from the device class onto a Material one.
IconData iconForBluetoothClass(String? icon) {
  switch (icon) {
    case 'audio-headset':
      return Icons.headset;
    case 'audio-headphones':
      return Icons.headphones;
    case 'audio-card':
      return Icons.audio_file;
    case 'audio-speakers':
      return Icons.speaker;
    case 'input-keyboard':
      return Icons.keyboard;
    case 'input-mouse':
      return Icons.mouse;
    case 'input-gaming':
      return Icons.sports_esports;
    case 'input-tablet':
      return Icons.tablet;
    case 'input-touchpad':
      return Icons.touch_app;
    case 'phone':
      return Icons.smartphone;
    case 'computer':
      return Icons.computer;
    case 'printer':
      return Icons.print;
    case 'scanner':
      return Icons.scanner;
    case 'camera-photo':
      return Icons.photo_camera;
    case 'camera-video':
      return Icons.videocam;
    case 'video-display':
      return Icons.tv;
    case 'multimedia-player':
      return Icons.music_note;
    case 'modem':
      return Icons.router;
    default:
      return Icons.bluetooth;
  }
}
