import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';

class BluetoothHeader extends StatelessWidget {
  const BluetoothHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isEnabled = context.select<BluetoothBloc, bool>(
      (bloc) => bloc.state.isEnabled,
    );
    final isDiscovering = context.select<BluetoothBloc, bool>(
      (bloc) => bloc.state.isDiscovering,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pair controllers, headsets, and input devices',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (isEnabled)
          IconButton.filledTonal(
            onPressed: () => context.read<BluetoothBloc>().add(
              isDiscovering
                  ? const StopDiscoveryEvent()
                  : const StartDiscoveryEvent(),
            ),
            icon: isDiscovering
                ? const Icon(Icons.stop_circle_outlined)
                : const Icon(Icons.bluetooth_searching),
            tooltip: isDiscovering ? 'Stop scanning' : 'Scan for devices',
          ),
      ],
    );
  }
}
