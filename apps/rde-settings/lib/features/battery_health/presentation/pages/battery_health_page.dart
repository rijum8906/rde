import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_event.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_state.dart';

class BatteryHealthPage extends StatelessWidget {
  const BatteryHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BatteryHealthBloc(),
      child: const BatteryHealthView(),
    );
  }
}

class BatteryHealthView extends StatelessWidget {
  const BatteryHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: BlocBuilder<BatteryHealthBloc, BatteryHealthState>(
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Battery Health',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor battery status, health performance, and power configurations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // Responsive Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visual Battery Card (Left/Top)
                        Expanded(
                          flex: isWide ? 4 : 0,
                          child: Column(
                            children: [
                              _buildVisualBatteryCard(context),
                              const SizedBox(height: 24),
                              _buildPowerManagementCard(context, state),
                            ],
                          ),
                        ),
                        if (isWide) const SizedBox(width: 32),
                        if (!isWide) const SizedBox(height: 32),

                        // Battery Stats & Health info (Right/Bottom)
                        Expanded(
                          flex: isWide ? 3 : 0,
                          child: Column(
                            children: [
                              _buildHealthStatsCard(context),
                              const SizedBox(height: 24),
                              _buildAppUsageCard(context),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisualBatteryCard(BuildContext context) {
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
                      'Discharging — 6h 45m remaining',
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

            // Animated Visual Battery Cylinder
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 0.88),
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
                              // Fill level
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
                              // Inside percentage overlay
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
                      // Battery terminal cap on the right
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

  Widget _buildPowerManagementCard(
    BuildContext context,
    BatteryHealthState state,
  ) {
    final theme = Theme.of(context);

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

            // Toggle 1
            SwitchListTile(
              title: const Text(
                'Power Saver Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Reduces hardware speed and turns down active brightness',
              ),
              value: state.powerSavingMode,
              onChanged: (val) {
                context.read<BatteryHealthBloc>().add(
                  TogglePowerSavingEvent(val),
                );
              },
            ),
            const Divider(height: 24),

            // Toggle 2
            SwitchListTile(
              title: const Text(
                'Battery Health Protection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Cap maximum battery charge level to prolong lithium battery lifespan',
              ),
              value: state.healthProtection,
              onChanged: (val) {
                context.read<BatteryHealthBloc>().add(
                  ToggleHealthProtectionEvent(val),
                );
              },
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
                onChanged: (val) {
                  context.read<BatteryHealthBloc>().add(
                    ChangeChargeLimitEvent(val),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatsCard(BuildContext context) {
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
            _buildStatRow(
              context,
              'Maximum Capacity',
              '94%',
              'Original capacity holds 94% volume status',
            ),
            const Divider(height: 20),
            _buildStatRow(
              context,
              'Cycle Count',
              '248 cycles',
              'Good operating life status',
            ),
            const Divider(height: 20),
            _buildStatRow(
              context,
              'Battery Temperature',
              '31 °C',
              'Normal thermal conditions',
            ),
            const Divider(height: 20),
            _buildStatRow(
              context,
              'Device Status',
              'Optimized',
              'No calibration actions needed',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    String desc,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAppUsageCard(BuildContext context) {
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
            _buildAppUsageRow(
              context,
              'Display & Panel Backend',
              0.42,
              Icons.desktop_windows,
            ),
            _buildAppUsageRow(
              context,
              'Wireless Radios (WiFi)',
              0.18,
              Icons.wifi,
            ),
            _buildAppUsageRow(
              context,
              'System Core Super daemon',
              0.11,
              Icons.dns,
            ),
            _buildAppUsageRow(
              context,
              'Other Services & Audio',
              0.04,
              Icons.volume_up,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageRow(
    BuildContext context,
    String name,
    double value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
