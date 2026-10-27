import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';

/// The radio identity card: adapter name, address, and the master power switch.
///
/// The discoverable toggle lives in [BluetoothVisibilityCard] because it is a
/// different kind of decision (a privacy setting, not a radio state), and
/// pairing it with the power switch made it read as a sub-option of "on".
class BluetoothAdapterCard extends StatelessWidget {
  const BluetoothAdapterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;
    final adapter = state.adapter!;
    final isBusy = state.busyAddress != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            _AdapterBadge(enabled: state.isEnabled),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adapter.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.isEnabled
                        ? (state.isDiscovering
                              ? 'Scanning for devices…'
                              : 'Ready • ${adapter.address}')
                        : 'Radio disabled',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: state.isEnabled,
              onChanged: isBusy
                  ? null
                  : (value) => context.read<BluetoothBloc>().add(
                      ToggleBluetoothPowerEvent(value),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded square that holds the Bluetooth glyph and animates its color when
/// the radio changes state. Kept private: it's only meaningful inside the
/// adapter card.
class _AdapterBadge extends StatelessWidget {
  const _AdapterBadge({required this.enabled});

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
        enabled ? Icons.bluetooth : Icons.bluetooth_disabled,
        color: enabled
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}
