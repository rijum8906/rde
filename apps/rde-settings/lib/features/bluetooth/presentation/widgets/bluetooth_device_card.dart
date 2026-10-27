import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_device_tile.dart';

class BluetoothDevicesCard extends StatelessWidget {
  const BluetoothDevicesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;
    final sections = <(String, List<BluetoothDevice>)>[
      ('Connected', state.connectedDevices),
      ('Paired Devices', state.pairedDevices),
      ('Available Devices', state.availableDevices),
    ].where((section) => section.$2.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Devices',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (state.isDiscovering) const RdeLoadingIndicator(size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.isDiscovering
                  ? 'Looking for devices in range. Put the device in '
                        'pairing mode so it shows up.'
                  : 'Scanning is stopped. Start a scan to find devices in '
                        'range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No devices yet. Start a scan and put the device you want '
                  'to pair with into pairing mode.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    section.$1.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 1.3,
                      fontSize: 10,
                    ),
                  ),
                ),
                for (final device in section.$2)
                  BluetoothDeviceTile(device: device),
              ],
          ],
        ),
      ),
    );
  }
}
