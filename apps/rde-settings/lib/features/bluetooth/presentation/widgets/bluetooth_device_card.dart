import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_devices_tile.dart';
import 'package:rde_settings/features/bluetooth/presentation/widgets/bluetooth_error_message.dart';

class BluetoothDevicesCard extends StatelessWidget {
  const BluetoothDevicesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;
    final sections = <(String, List<BluetoothDevice>)>[
      ('Connected', state.connectedDevices),
      ('Paired', state.pairedDevices),
      ('Available', state.availableDevices),
    ].where((section) => section.$2.isNotEmpty).toList();

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
            if (sections.isEmpty)
              const BluetoothEmptyMessage(
                text:
                    'No devices yet. Start a scan and put the device you '
                    'want to pair with into pairing mode.',
              )
            else
              for (final section in sections) ...[
                _SectionLabel(label: section.$1),
                const SizedBox(height: 8),
                _DeviceGroup(devices: section.$2, section: section.$1),
                const SizedBox(height: 16),
              ],
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

/// Small section label shown above a grouped surface ("Connected", "Paired",
/// "Available"). Uppercase is intentional here — it reads as a category, not
/// as a title — but the letter-spacing and weight match the rest of the app.
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

/// Rounded grouped surface that contains the rows of one section.
/// Connected devices use a primary tint so the active device stands out
/// without needing a per-row badge on every row.
class _DeviceGroup extends StatelessWidget {
  const _DeviceGroup({required this.devices, required this.section});

  final List<BluetoothDevice> devices;
  final String section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = section == 'Connected';

    return Container(
      decoration: BoxDecoration(
        color: isConnected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            BluetoothDeviceTile(device: devices[i]),
          ],
        ],
      ),
    );
  }
}
