import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/stat_row_card.dart';

/// Battery health statistics read from the UPower snapshot.
class HealthStatsCard extends StatelessWidget {
  const HealthStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = context.watch<BatteryHealthBloc>().state.snapshot;

    final health = snapshot?.healthPercent;
    final cycles = snapshot?.cycleCount;
    final temperature = snapshot?.temperatureCelsius;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Health',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StatRow(
              label: 'Maximum Capacity',
              value: health == null
                  ? 'Unknown'
                  : '${health.toStringAsFixed(1)}%',
              description: health == null
                  ? 'Health data not reported by this battery'
                  : 'Original capacity holds ${health.toStringAsFixed(1)}% of its design volume',
            ),
            const Divider(height: 20),
            StatRow(
              label: 'Cycle Count',
              value: cycles == null ? 'Unknown' : '$cycles cycles',
              description: cycles == null
                  ? 'Cycle count not reported by this battery'
                  : 'Total charge cycles reported by the battery',
            ),
            const Divider(height: 20),
            StatRow(
              label: 'Battery Temperature',
              value: temperature == null
                  ? 'Unknown'
                  : '${temperature.round()} °C',
              description: temperature == null
                  ? 'No temperature sensor on this battery'
                  : 'Reported by the battery sensor',
            ),
            const Divider(height: 20),
            StatRow(
              label: 'Device Status',
              value: snapshot?.deviceStatusLabel ?? 'Unknown',
              description:
                  snapshot?.deviceStatusDescription ??
                  'Health data not reported by this battery',
            ),
          ],
        ),
      ),
    );
  }
}
