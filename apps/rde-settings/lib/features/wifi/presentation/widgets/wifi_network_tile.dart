import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/utils/wifi_helpers.dart';

class WifiNetworkTile extends StatelessWidget {
  const WifiNetworkTile({
    super.key,
    required this.state,
    required this.network,
    required this.isConnected,
    required this.isConnecting,
    required this.isSaved,
    required this.onConnect,
    required this.onDisconnect,
  });

  final WifiState state;
  final WifiNetwork network;
  final bool isConnected;
  final bool isConnecting;
  final bool isSaved;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

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
            TextButton(
              onPressed: onDisconnect,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Disconnect'),
            )
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
