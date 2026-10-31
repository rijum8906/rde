import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_devices_tile.dart';

/// Side-by-side device columns: what is connected, and what a scan found.
///
/// The two lists answer two different questions ("what is in use?" and "what
/// could I add?"), so they sit next to each other instead of stacking into one
/// long section list. Paired devices have their own page, which keeps a bonded
/// device out of both columns' way.
class BluetoothDevicesCard extends StatelessWidget {
  const BluetoothDevicesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(isDiscovering: state.isDiscovering),
            const SizedBox(height: 4),
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
            LayoutBuilder(
              builder: (context, constraints) {
                // Two columns need room for a name, a button and a menu each;
                // below that the columns stack so no row has to overflow.
                final isWide = constraints.maxWidth > 900;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _DeviceColumn(
                        label: 'Connected',
                        icon: Icons.link,
                        devices: state.connectedDevices,
                        emptyText:
                            'Nothing is connected. Connect a device from the '
                            'list beside this column.',
                        highlighted: true,
                      ),
                    ),
                    if (isWide) const SizedBox(width: 20) else
                      const SizedBox(height: 20),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _DeviceColumn(
                        label: 'Available',
                        icon: Icons.bluetooth_searching,
                        devices: state.availableDevices,
                        emptyText:
                            'No devices in range. Start a scan and put the '
                            'device you want to pair with into pairing mode.',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Title row with the device icon and the "looking for devices" spinner.
class _Header extends StatelessWidget {
  const _Header({required this.isDiscovering});

  final bool isDiscovering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
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
        if (isDiscovering) const RdeLoadingIndicator(size: 18),
      ],
    );
  }
}

/// One column: a labelled heading with a device count and the grouped rows.
///
/// The connected column keeps the primary tint so the active devices stand out
/// without a per-row badge.
class _DeviceColumn extends StatelessWidget {
  const _DeviceColumn({
    required this.label,
    required this.icon,
    required this.devices,
    required this.emptyText,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final List<BluetoothDevice> devices;
  final String emptyText;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: highlighted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${devices.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: devices.isEmpty
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: highlighted
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: devices.isEmpty
              ? Text(
                  emptyText,
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
    );
  }
}
