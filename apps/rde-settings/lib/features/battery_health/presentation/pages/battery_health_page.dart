import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_state.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/app_usage_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/battery_health_header.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/health_state_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/power_management_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/visual_battery_card.dart';

/// Battery health settings backed by the battery subsystem.
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

/// Renders the state published by [BatteryHealthBloc].
///
/// The view only lays out the four cards; each card reads the state it
/// needs from the bloc. The two-column layout matches the Theme & Styling
/// page: a wide primary column on the left, a narrower stats column on the
/// right, stacked on narrow widths.
class BatteryHealthView extends StatelessWidget {
  const BatteryHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<BatteryHealthBloc, BatteryHealthState>(
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BatteryHealthHeader(),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isWide ? 4 : 0,
                          child: const Column(
                            children: [
                              VisualBatteryCard(),
                              SizedBox(height: 24),
                              PowerManagementCard(),
                            ],
                          ),
                        ),
                        if (isWide) const SizedBox(width: 32),
                        if (!isWide) const SizedBox(height: 32),
                        Expanded(
                          flex: isWide ? 3 : 0,
                          child: const Column(
                            children: [
                              HealthStatsCard(),
                              SizedBox(height: 24),
                              AppUsageCard(),
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
}
