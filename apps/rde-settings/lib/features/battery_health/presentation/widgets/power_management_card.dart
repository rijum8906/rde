import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_event.dart';

class PowerManagementCard extends StatelessWidget {
  const PowerManagementCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<BatteryHealthBloc>().state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Management',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Power Saver Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Reduces hardware speed and turns down active brightness',
              ),
              value: state.powerSavingMode,
              onChanged: (val) => context.read<BatteryHealthBloc>().add(
                TogglePowerSavingEvent(val),
              ),
            ),
            const Divider(height: 24),
            SwitchListTile(
              title: const Text(
                'Battery Health Protection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Cap maximum battery charge level to prolong lithium battery lifespan',
              ),
              value: state.healthProtection,
              onChanged: (val) => context.read<BatteryHealthBloc>().add(
                ToggleHealthProtectionEvent(val),
              ),
            ),
            if (state.healthProtection) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Max Charge Limit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(state.chargeLimit * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: state.chargeLimit,
                min: 0.6,
                max: 1.0,
                divisions: 8,
                onChanged: (val) => context.read<BatteryHealthBloc>().add(
                  ChangeChargeLimitEvent(val),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
