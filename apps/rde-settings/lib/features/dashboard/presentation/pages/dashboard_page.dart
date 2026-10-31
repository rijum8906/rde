import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/core/widgets/silky_scroll_config.dart';
import 'package:rde_settings/features/audio_io/data/datasources/dbus/volume_proxy.dart';
import 'package:rde_settings/features/audio_io/data/repositories/master_volume_repository_impl.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:rde_settings/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/get_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/domain/use_cases/save_dashboard_settings.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_state.dart';

// Import the widgets
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_system_health.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_personalization.dart';

import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = DashboardRepositoryImpl();
    final getUseCase = GetDashboardSettingsUseCase(repository);
    final saveUseCase = SaveDashboardSettingsUseCase(repository);

    final themeRepository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    final volumeRepository = MasterVolumeRepositoryImpl(VolumeProxy());

    return MultiBlocProvider(
      providers: [
        // DashBoard
        BlocProvider(
          create: (context) => DashboardBloc(
            getSettingsUseCase: getUseCase,
            saveSettingsUseCase: saveUseCase,
            updateDynamicTheme: UpdateDynamicThemeUseCase(themeRepository),
            setThemeUseCase: SetThemeUseCase(themeRepository),
            setModeUseCase: SetModeUseCase(themeRepository),
          )..add(const DashboardInitEvent()),
        ),
        // Volume
        BlocProvider(
          create: (context) =>
              VolumeBloc(repository: volumeRepository)
                ..add(const VolumeInitEvent()),
        ),
      ],
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading) {
            return const Center(child: RdeLoadingIndicator());
          }

          if (state.status == DashboardStatus.failure) {
            return Center(
              child: Text(
                'Failed to load settings: ${state.errorMessage}',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          return SilkySingleChildScrollView(
            silkyConfig: appSilkyScroll,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                Text(
                  'Dashboard',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System status and quick toggles',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // Two-column layout on wide screens
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Actions & Health
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DashboardQuickActions(state: state),
                                const SizedBox(height: 32),
                                DashboardSystemHealth(state: state),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Right Column: Personalization
                          Expanded(
                            flex: 2,
                            child: DashboardPersonalization(state: state),
                          ),
                        ],
                      );
                    }

                    // Stacked layout for narrow screens
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardQuickActions(state: state),
                        const SizedBox(height: 32),
                        DashboardSystemHealth(state: state),
                        const SizedBox(height: 32),
                        DashboardPersonalization(state: state),
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
