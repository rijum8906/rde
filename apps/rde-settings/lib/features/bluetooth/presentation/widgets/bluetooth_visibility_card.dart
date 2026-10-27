import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';

/// Makes the adapter visible to nearby devices so they can initiate pairing.
///
/// Separate from [BluetoothAdapterCard] because this is a privacy setting,
/// not a radio state; putting it next to the power switch made it look like a
/// sub-option of "on".
class BluetoothVisibilityCard extends StatelessWidget {
  const BluetoothVisibilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BluetoothBloc>().state;
    final adapter = state.adapter!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(
              state.isDiscoverable
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: state.isDiscoverable
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 2),
                  Text(
                    state.isDiscoverable
                        ? 'Visible to nearby devices as "${adapter.name}"'
                        : 'Hidden from other devices',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: state.isDiscoverable,
              onChanged: (value) => context.read<BluetoothBloc>().add(
                ToggleDiscoverableEvent(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
