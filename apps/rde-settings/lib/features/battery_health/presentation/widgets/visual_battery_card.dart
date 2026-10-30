import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';

/// Visual battery cylinder with the current charge level.
///
/// The level and the charging state come from the UPower snapshot, so the card
/// follows the daemon instead of showing a placeholder charge.
class VisualBatteryCard extends StatelessWidget {
  const VisualBatteryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<BatteryHealthBloc>().state.snapshot;

    return _VisualBatteryCardBody(
      level: ((snapshot?.percentage ?? 0) / 100).clamp(0.0, 1.0),
      isCharging: snapshot?.isCharging ?? false,
      statusLabel: snapshot?.timeRemainingLabel ?? 'Waiting for battery data',
    );
  }
}

class _VisualBatteryCardBody extends StatelessWidget {
  const _VisualBatteryCardBody({
    required this.level,
    required this.isCharging,
    required this.statusLabel,
  });

  final double level;
  final bool isCharging;
  final String statusLabel;

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
                      statusLabel,
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
                      Icon(
                        isCharging ? Icons.bolt : Icons.battery_std,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCharging ? 'Charging' : 'On battery',
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
