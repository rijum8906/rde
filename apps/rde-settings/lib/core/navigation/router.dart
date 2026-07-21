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
              Expanded(child: child),
            ],
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const DashboardPage()),
        ),
        GoRoute(
          path: '/wifi',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const WifiPage()),
        ),
        GoRoute(
          path: '/bluetooth',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const BluetoothPage()),
        ),
        GoRoute(
          path: '/network_proxy',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const NetworkProxyPage()),
        ),
        GoRoute(
          path: '/theme_styling',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const ThemeStylingPage()),
        ),
        GoRoute(
          path: '/wallpaper',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const WallpaperPage()),
        ),
        GoRoute(
          path: '/typography',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const TypographyPage()),
        ),
        GoRoute(
          path: '/interface_assets',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const InterfaceAssetsPage()),
        ),
        GoRoute(
          path: '/display',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const DisplayPage()),
        ),
        GoRoute(
          path: '/audio_io',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const AudioIoPage()),
        ),
        GoRoute(
          path: '/keyboard',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const KeyboardPage()),
        ),
        GoRoute(
          path: '/pointer',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const PointerPage()),
        ),
        GoRoute(
          path: '/wm_bindings',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const WmBindingsPage()),
        ),
        GoRoute(
          path: '/battery_health',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const BatteryHealthPage()),
        ),
        GoRoute(
          path: '/sleep_states',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const SleepStatesPage()),
        ),
        GoRoute(
          path: '/hardware_triggers',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const HardwareTriggersPage()),
        ),
        GoRoute(
          path: '/lock_screen',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const LockScreenPage()),
        ),
        GoRoute(
          path: '/user_profile',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const UserProfilePage()),
        ),
        GoRoute(
          path: '/system_privacy',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const SystemPrivacyPage()),
        ),
        GoRoute(
          path: '/about_rde',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const AboutRdePage()),
        ),
        GoRoute(
          path: '/environment',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const EnvironmentPage()),
        ),
        GoRoute(
          path: '/daemons',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const DaemonsPage()),
        ),
        GoRoute(
          path: '/engine_overrides',
          pageBuilder: (context, state) =>
              _buildTransitionPage(state, const EngineOverridesPage()),
        ),
      ],
    ),
  ],
);

/// A page that animates its entrance and exit using a premium Material 3 Horizontal Shared Axis (Slide & Fade) transition.
Page<dynamic> _buildTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Shared Axis X Transition:
      // Slide from right to center (incoming) and center to left (outgoing)

      final slideIn = Tween<Offset>(
        begin: const Offset(0.04, 0.0), // Starts slightly offset to the right
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));

      final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
        ),
      );

      final slideOut =
          Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.02, 0.0), // Slides slightly to the left
          ).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutQuart,
            ),
          );

      final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
      );

      return SlideTransition(
        position: slideOut,
        child: FadeTransition(
          opacity: fadeOut,
          child: SlideTransition(
            position: slideIn,
            child: FadeTransition(opacity: fadeIn, child: child),
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}
