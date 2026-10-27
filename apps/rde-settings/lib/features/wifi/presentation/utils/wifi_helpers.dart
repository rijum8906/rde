import 'package:flutter/material.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

/// Open networks get the plain Wi-Fi icon; anything else gets the lock.
IconData signalIconFor(String security) {
  return security == 'Open' ? Icons.wifi : Icons.wifi_lock;
}

/// "Security: WPA2 • Signal: 80% • Saved" — the subtitle under an SSID.
String subtitleForNetwork(WifiNetwork network, {required bool isSaved}) {
  final buffer = StringBuffer()
    ..write('Security: ${network.security}')
    ..write(' • Signal: ${network.strength}');
  if (isSaved) buffer.write(' • Saved');
  return buffer.toString();
}
