import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_empty_message.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_network_tile.dart';

/// Card that lists the access points the current scan found.
class WifiNetworksCard extends StatelessWidget {
  const WifiNetworksCard({
    super.key,
    required this.state,
    required this.isLoading,
    required this.onConnect,
  });

  final WifiState state;
  final bool isLoading;
  final ValueChanged<WifiNetwork> onConnect;

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
            _Header(isScanning: isLoading),
            const SizedBox(height: 4),
            Text(
              state.isWifiEnabled
                  ? 'Networks in range. Move closer to a router for a '
                        'stronger signal.'
                  : 'Enable the Wi-Fi radio to scan for networks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!state.isWifiEnabled)
              const WifiEmptyMessage(
                text: 'Wi-Fi is off. Turn the radio on to scan for networks.',
              )
            else if (state.networks.isEmpty)
              const WifiEmptyMessage(
                text: 'No networks found. Move closer to a router or rescan.',
              )
            else
              _NetworksGroup(
                networks: state.networks,
                state: state,
                onConnect: onConnect,
              ),
          ],
        ),
      ),
    );
  }
}

/// Title row with the Wi-Fi icon and the "scanning" spinner.
class _Header extends StatelessWidget {
  const _Header({required this.isScanning});

  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.wifi_find, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Networks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        if (isScanning) const RdeLoadingIndicator(size: 18),
      ],
    );
  }
}

/// Rounded grouped surface containing the network rows.
class _NetworksGroup extends StatelessWidget {
  const _NetworksGroup({
    required this.networks,
    required this.state,
    required this.onConnect,
  });

  final List<WifiNetwork> networks;
  final WifiState state;
  final ValueChanged<WifiNetwork> onConnect;

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
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            WifiNetworkTile(
              state: state,
              network: networks[i],
              isConnected: state.connectedSsid == networks[i].ssid,
              isConnecting: state.connectingSsid == networks[i].ssid,
              isSaved: state.savedNetworks.any(
                (saved) => saved.ssid == networks[i].ssid,
              ),
              onConnect: () => onConnect(networks[i]),
            ),
          ],
        ],
      ),
    );
  }
}
