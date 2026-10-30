import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_devices_tile.dart';

/// The paired-device section of the Bluetooth page.
///
/// Lists every device this controller has a bond with, whether or not it is
/// connected: bonded devices are the ones that reconnect on their own, so they
/// deserve their own page instead of being mixed into the scan results. Each
/// row keeps the shared [BluetoothDeviceTile] actions, so connect, trust and
/// forget work exactly as they do on the device columns.
class BluetoothPairedPage extends StatelessWidget {
  const BluetoothPairedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;
    final devices = state.pairedDevices;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth_connected,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paired Devices',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${devices.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Devices bonded to this controller. They reconnect on their own '
              'when they are in range and trusted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: devices.isEmpty
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: devices.isEmpty
                  ? Text(
                      'No paired devices yet. Pair a device from the Devices '
                      'section and it appears here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < devices.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 64,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          BluetoothDeviceTile(device: devices[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
