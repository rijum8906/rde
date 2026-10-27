import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/utils/wifi_helpers.dart';

/// One scanned access point.
///
/// Layout mirrors `BluetoothDeviceTile`: a fixed 40×40 avatar, an `Expanded`
/// label (so long SSIDs truncate instead of pushing the action off-screen),
/// and a fixed trailing area (pill / spinner / compact button).
class WifiNetworkTile extends StatelessWidget {
  const WifiNetworkTile({
    super.key,
    required this.state,
    required this.network,
    required this.isConnected,
    required this.isConnecting,
    required this.isSaved,
    required this.onConnect,
  });

  final WifiState state;
  final WifiNetwork network;
  final bool isConnected;
  final bool isConnecting;
  final bool isSaved;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          _NetworkAvatar(network: network, connected: isConnected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  network.ssid,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isConnected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                Text(
                  subtitleForNetwork(network, isSaved: isSaved),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isConnected)
            const _ConnectedBadge()
          else if (isConnecting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: RdeLoadingIndicator(size: 20),
            )
          else
            FilledButton.tonal(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}

/// Rounded square holding the security icon. Tinted when connected,
/// matching `_DeviceAvatar` in `bluetooth_devices_tile.dart`.
class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({required this.network, required this.connected});

  final WifiNetwork network;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: connected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          signalIconFor(network.security),
          size: 20,
          color: connected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "Connected" pill shown in the trailing slot, same shape and colors as
/// `_ConnectedBadge` in `bluetooth_devices_tile.dart`.
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
