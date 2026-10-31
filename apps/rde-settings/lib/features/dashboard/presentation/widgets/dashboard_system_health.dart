import 'dart:async';

import 'package:flutter/material.dart';

/// CPU, memory, and battery gauges for the dashboard.
///
/// No service bloc owns these readings yet, so the widget keeps a small local
/// sample that refreshes every few seconds to keep the gauges alive.
class DashboardSystemHealth extends StatefulWidget {
  const DashboardSystemHealth({super.key});

  @override
  State<DashboardSystemHealth> createState() => _DashboardSystemHealthState();
}

class _DashboardSystemHealthState extends State<DashboardSystemHealth> {
  double _cpuUsage = 0.38;
  double _ramUsage = 0.54;
  double _batteryLevel = 0.88;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _statsTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      setState(() {
        _cpuUsage = (0.25 + (timer.tick % 5) * 0.05).clamp(0.0, 1.0);
        _ramUsage = (0.50 + (timer.tick % 3) * 0.02).clamp(0.0, 1.0);
        _batteryLevel = (0.88 - (timer.tick * 0.001)).clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

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
                  percentage: _cpuUsage,
                  color: colorScheme.primary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'RAM',
                  percentage: _ramUsage,
                  color: colorScheme.secondary,
                ),
                _buildCircularGauge(
                  context: context,
                  label: 'Battery',
                  percentage: _batteryLevel,
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
