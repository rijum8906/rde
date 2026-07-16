import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rde_settings/core/widgets/navigation_sidebar.dart';
import 'package:rde_settings/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rde_settings/features/wifi/presentation/pages/wifi_page.dart';
import 'package:rde_settings/features/bluetooth/presentation/pages/bluetooth_page.dart';
import 'package:rde_settings/features/network_proxy/presentation/pages/network_proxy_page.dart';
import 'package:rde_settings/features/theme_styling/presentation/pages/theme_styling_page.dart';
import 'package:rde_settings/features/wallpaper/presentation/pages/wallpaper_page.dart';
import 'package:rde_settings/features/typography/presentation/pages/typography_page.dart';
import 'package:rde_settings/features/interface_assets/presentation/pages/interface_assets_page.dart';
import 'package:rde_settings/features/display/presentation/pages/display_page.dart';
import 'package:rde_settings/features/audio_io/presentation/pages/audio_io_page.dart';
import 'package:rde_settings/features/keyboard/presentation/pages/keyboard_page.dart';
import 'package:rde_settings/features/pointer/presentation/pages/pointer_page.dart';
import 'package:rde_settings/features/wm_bindings/presentation/pages/wm_bindings_page.dart';
import 'package:rde_settings/features/battery_health/presentation/pages/battery_health_page.dart';
import 'package:rde_settings/features/sleep_states/presentation/pages/sleep_states_page.dart';
import 'package:rde_settings/features/hardware_triggers/presentation/pages/hardware_triggers_page.dart';
import 'package:rde_settings/features/lock_screen/presentation/pages/lock_screen_page.dart';
import 'package:rde_settings/features/user_profile/presentation/pages/user_profile_page.dart';
import 'package:rde_settings/features/system_privacy/presentation/pages/system_privacy_page.dart';
import 'package:rde_settings/features/about_rde/presentation/pages/about_rde_page.dart';
import 'package:rde_settings/features/environment/presentation/pages/environment_page.dart';
import 'package:rde_settings/features/daemons/presentation/pages/daemons_page.dart';
import 'package:rde_settings/features/engine_overrides/presentation/pages/engine_overrides_page.dart';

final router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationSidebar(currentPath: state.matchedLocation),
              Expanded(
                child: child,
              ),
            ],
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/wifi',
          builder: (context, state) => const WifiPage(),
        ),
        GoRoute(
          path: '/bluetooth',
          builder: (context, state) => const BluetoothPage(),
        ),
        GoRoute(
          path: '/network_proxy',
          builder: (context, state) => const NetworkProxyPage(),
        ),
        GoRoute(
          path: '/theme_styling',
          builder: (context, state) => const ThemeStylingPage(),
        ),
        GoRoute(
          path: '/wallpaper',
          builder: (context, state) => const WallpaperPage(),
        ),
        GoRoute(
          path: '/typography',
          builder: (context, state) => const TypographyPage(),
        ),
        GoRoute(
          path: '/interface_assets',
          builder: (context, state) => const InterfaceAssetsPage(),
        ),
        GoRoute(
          path: '/display',
          builder: (context, state) => const DisplayPage(),
        ),
        GoRoute(
          path: '/audio_io',
          builder: (context, state) => const AudioIoPage(),
        ),
        GoRoute(
          path: '/keyboard',
          builder: (context, state) => const KeyboardPage(),
        ),
        GoRoute(
          path: '/pointer',
          builder: (context, state) => const PointerPage(),
        ),
        GoRoute(
          path: '/wm_bindings',
          builder: (context, state) => const WmBindingsPage(),
        ),
        GoRoute(
          path: '/battery_health',
          builder: (context, state) => const BatteryHealthPage(),
        ),
        GoRoute(
          path: '/sleep_states',
          builder: (context, state) => const SleepStatesPage(),
        ),
        GoRoute(
          path: '/hardware_triggers',
          builder: (context, state) => const HardwareTriggersPage(),
        ),
        GoRoute(
          path: '/lock_screen',
          builder: (context, state) => const LockScreenPage(),
        ),
        GoRoute(
          path: '/user_profile',
          builder: (context, state) => const UserProfilePage(),
        ),
        GoRoute(
          path: '/system_privacy',
          builder: (context, state) => const SystemPrivacyPage(),
        ),
        GoRoute(
          path: '/about_rde',
          builder: (context, state) => const AboutRdePage(),
        ),
        GoRoute(
          path: '/environment',
          builder: (context, state) => const EnvironmentPage(),
        ),
        GoRoute(
          path: '/daemons',
          builder: (context, state) => const DaemonsPage(),
        ),
        GoRoute(
          path: '/engine_overrides',
          builder: (context, state) => const EngineOverridesPage(),
        ),
      ],
    ),
  ],
);
