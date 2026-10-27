import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_empty_message.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_network_tile.dart';

/// Card that lists the access points the current scan found.
///
/// The networks are grouped by connection state — Connected first, then
/// Available — matching `BluetoothDevicesCard`'s sectioning. The connected
/// network is *moved* into its own group rather than shown twice, so a scan
/// that includes the active network shows it once, at the top.
class WifiNetworksCard extends StatelessWidget {
  const WifiNetworksCard({
    super.key,
    required this.state,
    required this.isLoading,
    required this.onConnect,
    required this.onDisconnect,
  });

  final WifiState state;
  final bool isLoading;
  final ValueChanged<WifiNetwork> onConnect;
  final ValueChanged<WifiNetwork> onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Split the scan into the two sections the card renders.
    // A network is "connected" if its SSID matches `connectedSsid`;
    // everything else is "available". Empty groups are not rendered.
    final connected = state.networks
        .where((n) => n.ssid == state.connectedSsid)
        .toList();
    final available = state.networks
        .where((n) => n.ssid != state.connectedSsid)
        .toList();
    final sections = <(String, List<WifiNetwork>)>[
      ('Connected', connected),
      ('Available', available),
    ].where((section) => section.$2.isNotEmpty).toList();

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
            else if (sections.isEmpty)
              const WifiEmptyMessage(
                text: 'No networks found. Move closer to a router or rescan.',
              )
            else
              for (final section in sections) ...[
                _SectionLabel(label: section.$1),
                const SizedBox(height: 8),
                _NetworksGroup(
                  networks: section.$2,
                  state: state,
                  onConnect: onConnect,
                  onDisconnect: onDisconnect,
                ),
                const SizedBox(height: 16),
              ],
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

/// Small section label above a grouped surface ("Connected", "Available").
/// Matches `_SectionLabel` in `bluetooth_device_card.dart` exactly.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Rounded grouped surface containing the network rows.
///
/// Connected rows use a primary tint, matching `_DeviceGroup`'s
/// Connected section in `bluetooth_device_card.dart`.
class _NetworksGroup extends StatelessWidget {
  const _NetworksGroup({
    required this.networks,
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
  });

  final List<WifiNetwork> networks;
  final WifiState state;
  final ValueChanged<WifiNetwork> onConnect;
  final ValueChanged<WifiNetwork> onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnectedGroup = networks.any((n) => n.ssid == state.connectedSsid);

    return Container(
      decoration: BoxDecoration(
        color: isConnectedGroup
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
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
            WifiNetworkTile(
              state: state,
              network: networks[i],
              isConnected: state.connectedSsid == networks[i].ssid,
              isConnecting: state.connectingSsid == networks[i].ssid,
              isSaved: state.savedNetworks.any(
                (saved) => saved.ssid == networks[i].ssid,
              ),
              onConnect: () => onConnect(networks[i]),
              onDisconnect: () => onDisconnect(networks[i]),
            ),
          ],
        ],
      ),
    );
  }
}
