import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                signalIconFor(network.security),
                size: 20,
                color: isConnected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    network.ssid,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isConnected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitleForNetwork(network, isSaved: isSaved),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else if (isConnecting)
            const RdeLoadingIndicator(size: 24)
          else
            TextButton(onPressed: onConnect, child: const Text('Connect')),
        ],
      ),
    );
  }
}
