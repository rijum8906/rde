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
        padding: const EdgeInsets.all(20.0),
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
                Expanded(
                  child: Text(
                    'Saved Devices & Profiles',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
              _SavedGroup(
                networks: state.savedNetworks,
                state: state,
                onConnect: onConnect,
                onForget: onForget,
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedGroup extends StatelessWidget {
  const _SavedGroup({
    required this.networks,
    required this.state,
    required this.onConnect,
    required this.onForget,
  });

  final List<WifiNetwork> networks;
  final WifiState state;
  final ValueChanged<WifiNetwork> onConnect;
  final ValueChanged<WifiNetwork> onForget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < networks.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            WifiSavedTile(
              network: networks[i],
              isConnected: state.connectedSsid == networks[i].ssid,
              isConnecting: state.connectingSsid == networks[i].ssid,
              onConnect: () => onConnect(networks[i]),
              onForget: () => onForget(networks[i]),
            ),
          ],
        ],
      ),
    );
  }
}
