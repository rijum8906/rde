import 'package:flutter/material.dart';

/// A single resource-drain row: icon, name, percentage, and a progress bar.
class AppUsageRow extends StatelessWidget {
  const AppUsageRow({
    super.key,
    required this.name,
    required this.value,
    required this.icon,
  });

  /// Human-readable label (e.g. "Display & Panel Backend").
  final String name;

  /// Fraction in 0.0–1.0. Rendered as a percentage and a progress bar.
  final double value;

  /// Leading icon that identifies the resource class.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: value,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
