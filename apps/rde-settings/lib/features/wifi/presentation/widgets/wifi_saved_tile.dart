import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/domain/entities/wifi_network.dart';

/// One saved profile.
///
/// Layout mirrors `BluetoothDeviceTile` and `WifiNetworkTile`: a fixed
/// 40×40 avatar, an `Expanded` label, and a trailing area that switches
/// between a Connected pill, a spinner, and a Connect button + kebab.
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          _SavedAvatar(connected: isConnected),
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
                  isConnected ? 'Currently Connected' : 'Saved Profile',
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
            const _SavedConnectedBadge()
          else if (isConnecting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: RdeLoadingIndicator(size: 20),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'forget') onForget();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'forget', child: Text('Forget')),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SavedAvatar extends StatelessWidget {
  const _SavedAvatar({required this.connected});

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
          Icons.bookmark_added_outlined,
          size: 20,
          color: connected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SavedConnectedBadge extends StatelessWidget {
  const _SavedConnectedBadge();

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
