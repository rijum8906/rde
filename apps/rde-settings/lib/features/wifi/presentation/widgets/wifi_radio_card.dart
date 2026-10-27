import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_state.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_empty_message.dart';
import 'package:rde_settings/features/wifi/presentation/widgets/wifi_network_tile.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class WifiRadioCard extends StatelessWidget {
  const WifiRadioCard({
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _RadioRow(state: state),
            if (state.isWifiEnabled) ...[
              const Divider(height: 32),
              if (isLoading && state.networks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(child: RdeLoadingIndicator()),
                )
              else if (state.networks.isEmpty)
                const WifiEmptyMessage(
                  text: 'No networks found. Move closer to a router or rescan.',
                )
              else
                Column(
                  children: List.generate(state.networks.length, (index) {
                    final network = state.networks[index];
                    return Column(
                      children: [
                        if (index > 0) const Divider(),
                        WifiNetworkTile(
                          state: state,
                          network: network,
                          isConnected: state.connectedSsid == network.ssid,
                          isConnecting: state.connectingSsid == network.ssid,
                          isSaved: state.savedNetworks.any(
                            (saved) => saved.ssid == network.ssid,
                          ),
                          onConnect: () => onConnect(network),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The master radio switch + connection status line.
class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.state});

  final WifiState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: state.isWifiEnabled
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                state.isWifiEnabled ? Icons.wifi : Icons.wifi_off,
                color: state.isWifiEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wi-Fi Radio',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  state.isWifiEnabled
                      ? (state.connectedSsid != null
                            ? 'Connected to ${state.connectedSsid}'
                            : 'Ready to connect')
                      : 'Radio Disabled',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        Switch(
          value: state.isWifiEnabled,
          onChanged: (value) =>
              context.read<WifiBloc>().add(ToggleWifiRadioEvent(value)),
        ),
      ],
    );
  }
}
