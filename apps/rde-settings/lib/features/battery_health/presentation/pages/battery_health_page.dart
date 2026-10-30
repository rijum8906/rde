import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/silky_scroll_config.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus/power_profiles_proxy.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus/upower_proxy.dart';
import 'package:rde_settings/features/battery_health/data/datasources/dbus_battery_health_datasource.dart';
import 'package:rde_settings/features/battery_health/data/repositories/battery_health_repository_impl.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/read_battery_health.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_end_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_charge_threshold.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/set_power_profile.dart';
import 'package:rde_settings/features/battery_health/domain/use_cases/watch_battery_health.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_bloc.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_event.dart';
import 'package:rde_settings/features/battery_health/presentation/bloc/battery_health_state.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/battery_health_header.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/health_state_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/power_management_card.dart';
import 'package:rde_settings/features/battery_health/presentation/widgets/visual_battery_card.dart';

class BatteryHealthPage extends StatelessWidget {
  const BatteryHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final upower = UPowerProxy();
    final powerProfiles = PowerProfilesProxy();
    final datasource = DbusBatteryHealthDatasource(
      upower: upower,
      powerProfiles: powerProfiles,
    );
    final repository = BatteryHealthRepositoryImpl(datasource);

    return BlocProvider(
      create: (_) => BatteryHealthBloc(
        read: ReadBatteryHealthUseCase(repository),
        watch: WatchBatteryHealthUseCase(repository),
        setChargeThreshold: SetChargeThresholdUseCase(repository),
        setChargeEndThreshold: SetChargeEndThresholdUseCase(repository),
        setPowerProfile: SetPowerProfileUseCase(repository),
      )..add(const BatteryHealthInitEvent()),
      child: const BatteryHealthView(),
    );
  }
}

class BatteryHealthView extends StatelessWidget {
  const BatteryHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<BatteryHealthBloc, BatteryHealthState>(
        builder: (context, state) {
          return SilkySingleChildScrollView(
            silkyConfig: appSilkyScroll,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BatteryHealthHeader(),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: state.errorMessage!),
                ],
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
                          child: const HealthStatsCard(),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
