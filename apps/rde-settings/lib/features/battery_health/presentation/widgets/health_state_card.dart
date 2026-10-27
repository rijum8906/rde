import 'package:flutter/material.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/stat_row_card.dart';

class HealthStatsCard extends StatelessWidget {
  const HealthStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            const StatRow(
              label: 'Maximum Capacity',
              value: '94%',
              description: 'Original capacity holds 94% volume status',
            ),
            const Divider(height: 20),
            const StatRow(
              label: 'Cycle Count',
              value: '248 cycles',
              description: 'Good operating life status',
            ),
            const Divider(height: 20),
            const StatRow(
              label: 'Battery Temperature',
              value: '31 °C',
              description: 'Normal thermal conditions',
            ),
            const Divider(height: 20),
            const StatRow(
              label: 'Device Status',
              value: 'Optimized',
              description: 'No calibration actions needed',
            ),
          ],
        ),
      ),
    );
  }
}
