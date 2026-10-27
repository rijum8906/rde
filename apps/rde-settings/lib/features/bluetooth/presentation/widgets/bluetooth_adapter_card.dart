import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_state.dart';

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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: state.isEnabled
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        state.isEnabled
                            ? Icons.bluetooth
                            : Icons.bluetooth_disabled,
                        color: state.isEnabled
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
                          adapter.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  ],
                ),
                Switch(
                  value: state.isEnabled,
                  onChanged: isBusy
                      ? null
                      : (value) => context.read<BluetoothBloc>().add(
                          ToggleBluetoothPowerEvent(value),
                        ),
                ),
              ],
            ),
            if (state.isEnabled) ...[
              const Divider(height: 32),
              _DiscoverableRow(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiscoverableRow extends StatelessWidget {
  const _DiscoverableRow({required this.state});

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adapter = state.adapter!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discoverable',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                state.isDiscoverable
                    ? 'Other devices can find "${adapter.name}"'
                    : 'Hidden from other devices',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: state.isDiscoverable,
          onChanged: (value) =>
              context.read<BluetoothBloc>().add(ToggleDiscoverableEvent(value)),
        ),
      ],
    );
  }
}
