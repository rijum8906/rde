import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/core/widgets/silky_scroll_config.dart';
import 'package:rde_settings/features/audio_io/data/datasources/dbus/volume_proxy.dart';
import 'package:rde_settings/features/audio_io/data/repositories/master_volume_repository_impl.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus/bluez_proxy.dart';
import 'package:rde_settings/features/bluetooth/data/datasources/dbus_bluetooth_datasource.dart';
import 'package:rde_settings/features/bluetooth/domain/repositories/bluetooth_repository_impl.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_bloc.dart';
import 'package:rde_settings/features/bluetooth/presentation/bloc/bluetooth_event.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus/network_manager_proxy.dart';
import 'package:rde_settings/features/wifi/data/datasources/dbus_wifi_datasource.dart';
import 'package:rde_settings/features/wifi/domain/repositories/wifi_repository_impl.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';
import 'package:silky_scroll/silky_scroll.dart';

import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_system_health.dart';
import 'package:rde_settings/features/dashboard/presentation/widgets/dashboard_personalization.dart';

/// Dashboard overview of the desktop's quick settings services.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wifiRepository = WifiRepositoryImpl(
      DbusWifiDatasource(NetworkManagerProxy()),
    );

    final volumeRepository = MasterVolumeRepositoryImpl(VolumeProxy());
    final bluetoothRepository = BluetoothRepositoryImpl(
      DbusBluetoothDatasource(BluezProxy()),
    );
    final themeRepository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    // Each card renders the state of the service that owns it, so the page
    // provides those blocs instead of keeping a duplicate dashboard copy.
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              VolumeBloc(repository: volumeRepository)
                ..add(const VolumeInitEvent()),
        ),
        BlocProvider(
          create: (context) =>
              WifiBloc(wifiRepository: wifiRepository)
                ..add(const WifiInitEvent()),
        ),
        BlocProvider(
          create: (context) =>
              BluetoothBloc(bluetoothRepository: bluetoothRepository)
                ..add(const BluetoothInitEvent()),
        ),
        BlocProvider(
          create: (context) =>
              ThemeBloc(repository: themeRepository)
                ..add(const ThemeInitEvent()),
        ),
      ],
      child: const DashboardView(),
    );
  }
}

/// Scrollable dashboard layout.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SilkySingleChildScrollView(
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
                            const DashboardQuickActions(),
                            const SizedBox(height: 32),
                            const DashboardSystemHealth(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right Column: Personalization
                      Expanded(
                        flex: 2,
                        child: const DashboardPersonalization(),
                      ),
                    ],
                  );
                }

                // Stacked layout for narrow screens
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardQuickActions(),
                    SizedBox(height: 32),
                    DashboardSystemHealth(),
                    SizedBox(height: 32),
                    DashboardPersonalization(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
