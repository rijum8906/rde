import 'package:flutter/material.dart';

/// Visual battery cylinder with the current charge level.
class VisualBatteryCard extends StatelessWidget {
  const VisualBatteryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _VisualBatteryCardBody(
      // If BatteryHealthState exposes a `batteryLevel` (0.0–1.0), read it
      // here. Otherwise fall back to the previous hardcoded 0.88.
      level: 0.88,
      isCharging: false,
    );
  }
}

class _VisualBatteryCardBody extends StatelessWidget {
  const _VisualBatteryCardBody({required this.level, required this.isCharging});

  final double level;
  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Power Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCharging
                          ? 'Charging — ${(level * 100).toInt()}%'
                          : 'Discharging — 6h 45m remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Standard',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: level),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOutBack,
                builder: (context, chargeValue, _) {
                  return Column(
                    children: [
                      Center(
                        child: Container(
                          width: 200,
                          height: 90,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: (200 - 20) * chargeValue,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[400]!,
                                      Colors.green[600]!,
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  '${(chargeValue * 100).toInt()}%',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 14,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorScheme.outline,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
