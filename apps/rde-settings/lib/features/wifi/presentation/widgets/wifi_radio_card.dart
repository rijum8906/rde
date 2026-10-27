import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';

/// Identity card: the adapter name, connection status, the radio switch, and
/// a small scan spinner in the top-right while a scan is running.
///
/// The spinner mirrors the Bluetooth adapter card's "is something happening
/// right now" signal and lives next to the switch (not replacing it) so the
/// switch never moves while a scan is in flight.
class WifiIdentityCard extends StatelessWidget {
  const WifiIdentityCard({super.key, required this.isScanning});

  /// True while a scan is in progress. Controls the small trailing spinner
  /// next to the radio switch.
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<WifiBloc>().state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            _WifiBadge(enabled: state.isWifiEnabled),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wi-Fi',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.isWifiEnabled
                        ? (state.connectedSsid != null
                              ? 'Connected to ${state.connectedSsid}'
                              : 'Ready to connect')
                        : 'Radio disabled',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded square that holds the Wi-Fi glyph and animates its color when the
/// radio changes state. Mirrors `_AdapterBadge` in `bluetooth_adapter_card.dart`.
class _WifiBadge extends StatelessWidget {
  const _WifiBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        enabled ? Icons.wifi : Icons.wifi_off,
        color: enabled
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}
