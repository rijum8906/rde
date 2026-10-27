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
    final snapshot = state.snapshot;
    final isBusy = state.isBusy;

    // Charge threshold support depends on the snapshot. Before the first
    // read, treat it as unsupported (the switch is disabled) rather than
    // letting the user toggle a setting the device might not have.
    final thresholdSupported = snapshot?.chargeThresholdSupported ?? false;
    final thresholdEnabled = snapshot?.chargeThresholdEnabled ?? false;
    final chargeLimit = (snapshot?.chargeEndThreshold ?? 0) / 100.0;

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

            // ── Power Saver ──────────────────────────────────────────────
            SwitchListTile(
              title: const Text(
                'Power Saver Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Reduces hardware speed and turns down active brightness',
              ),
              value: state.powerSaverActive,
              onChanged: isBusy
                  ? null
                  : (val) => context.read<BatteryHealthBloc>().add(
                      TogglePowerSavingEvent(val),
                    ),
            ),

            const Divider(height: 24),

            // ── Health Protection ────────────────────────────────────────
            // Reads from `snapshot.chargeThresholdEnabled`, not from
            // `powerSaverActive`. Disabled when the battery doesn't report
            // `ChargeThresholdSupported`, so the switch can't be toggled on
            // hardware that has no threshold driver.
            SwitchListTile(
              title: const Text(
                'Battery Health Protection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                thresholdSupported
                    ? 'Cap maximum battery charge level to prolong lithium battery lifespan'
                    : 'This battery does not report charge-threshold support',
              ),
              value: thresholdEnabled,
              onChanged: !thresholdSupported || isBusy
                  ? null
                  : (val) => context.read<BatteryHealthBloc>().add(
                      ToggleHealthProtectionEvent(val),
                    ),
            ),

            // ── Charge limit slider ──────────────────────────────────────
            // Only shown when the threshold is enabled: the slider edits
            // `ChargeEndThreshold`, which only has meaning when the
            // threshold is active.
            if (thresholdEnabled) ...[
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
                      '${(chargeLimit * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: chargeLimit.clamp(0.6, 1.0),
                min: 0.6,
                max: 1.0,
                divisions: 8,
                onChanged: isBusy
                    ? null
                    : (val) => context.read<BatteryHealthBloc>().add(
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
