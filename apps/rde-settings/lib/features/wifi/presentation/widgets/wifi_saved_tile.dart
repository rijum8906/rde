import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

class WifiSavedTile extends StatelessWidget {
  const WifiSavedTile({
    super.key,
    required this.network,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
    required this.onForget,
  });

  final WifiNetwork network;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onForget;

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
                Icons.bookmark_added_outlined,
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
                    isConnected ? 'Currently Connected' : 'Saved Profile',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (!isConnected) ...[
                if (isConnecting)
                  const RdeLoadingIndicator(size: 24)
                else
                  TextButton(
                    onPressed: onConnect,
                    child: const Text('Connect'),
                  ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: onForget,
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error.withValues(alpha: 0.8),
                ),
                tooltip: 'Forget Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
