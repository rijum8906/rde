import 'package:flutter/material.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/app_usage_row.dart';

class AppUsageCard extends StatelessWidget {
  const AppUsageCard({super.key});

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
              'Resource Power Drain',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const AppUsageRow(
              name: 'Display & Panel Backend',
              value: 0.42,
              icon: Icons.desktop_windows,
            ),
            const AppUsageRow(
              name: 'Wireless Radios (WiFi)',
              value: 0.18,
              icon: Icons.wifi,
            ),
            const AppUsageRow(
              name: 'System Core Super daemon',
              value: 0.11,
              icon: Icons.dns,
            ),
            const AppUsageRow(
              name: 'Other Services & Audio',
              value: 0.04,
              icon: Icons.volume_up,
            ),
          ],
        ),
      ),
    );
  }
}
