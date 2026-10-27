import 'package:flutter/material.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_empty_message.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_saved_tile.dart';

class WifiSavedCard extends StatelessWidget {
  const WifiSavedCard({
    super.key,
    required this.state,
    required this.onConnect,
    required this.onForget,
  });

  final WifiState state;
  final ValueChanged<WifiNetwork> onConnect;
  final ValueChanged<WifiNetwork> onForget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Saved Devices & Profiles',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Profiles NetworkManager reconnects to automatically. '
              'Connect uses the stored credentials.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (state.savedNetworks.isEmpty)
              const WifiEmptyMessage(
                text:
                    'No saved devices yet. Join a network once and it '
                    'appears here.',
              )
            else
              Column(
                children: List.generate(state.savedNetworks.length, (index) {
                  final network = state.savedNetworks[index];
                  return Column(
                    children: [
                      if (index > 0) const Divider(),
                      WifiSavedTile(
                        network: network,
                        isConnected: state.connectedSsid == network.ssid,
                        isConnecting: state.connectingSsid == network.ssid,
                        onConnect: () => onConnect(network),
                        onForget: () => onForget(network),
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
