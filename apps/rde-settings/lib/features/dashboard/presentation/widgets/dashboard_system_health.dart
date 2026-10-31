import 'package:flutter/material.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardSystemHealth extends StatelessWidget {
  const DashboardSystemHealth({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularGauge(
                  context: context,
                  label: 'CPU',
                  percentage: state.cpuUsage,
                  color: colorScheme.primary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'RAM',
                  percentage: state.ramUsage,
                  color: colorScheme.secondary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'Battery',
                  percentage: state.batteryLevel,
                  color: const Color(0xFF006E3C),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularGauge({
    required BuildContext context,
    required String label,
    required double percentage,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: val,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '${(val * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
