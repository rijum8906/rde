import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rde_settings/core/widgets/navigation_sidebar.dart';
import 'package:rde_settings/features/about_rde/presentation/pages/about_rde_page.dart';
import 'package:rde_settings/features/audio_io/presentation/pages/audio_io_page.dart';
import 'package:rde_settings/features/battery_health/presentation/pages/battery_health_page.dart';
import 'package:rde_settings/features/bluetooth/presentation/pages/bluetooth_page.dart';
import 'package:rde_settings/features/daemons/presentation/pages/daemons_page.dart';
import 'package:rde_settings/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rde_settings/features/display/presentation/pages/display_page.dart';
import 'package:rde_settings/features/engine_overrides/presentation/pages/engine_overrides_page.dart';
import 'package:rde_settings/features/environment/presentation/pages/environment_page.dart';
import 'package:rde_settings/features/hardware_triggers/presentation/pages/hardware_triggers_page.dart';
import 'package:rde_settings/features/interface_assets/presentation/pages/interface_assets_page.dart';
import 'package:rde_settings/features/keyboard/presentation/pages/keyboard_page.dart';
import 'package:rde_settings/features/lock_screen/presentation/pages/lock_screen_page.dart';
import 'package:rde_settings/features/network_proxy/presentation/pages/network_proxy_page.dart';
import 'package:rde_settings/features/pointer/presentation/pages/pointer_page.dart';
import 'package:rde_settings/features/sleep_states/presentation/pages/sleep_states_page.dart';
import 'package:rde_settings/features/system_privacy/presentation/pages/system_privacy_page.dart';
import 'package:rde_settings/features/theme_styling/presentation/pages/theme_styling_page.dart';
import 'package:rde_settings/features/typography/presentation/pages/typography_page.dart';
import 'package:rde_settings/features/user_profile/presentation/pages/user_profile_page.dart';
import 'package:rde_settings/features/wallpaper/presentation/pages/wallpaper_page.dart';
import 'package:rde_settings/features/wifi/presentation/pages/wifi_page.dart';
import 'package:rde_settings/features/wm_bindings/presentation/pages/wm_bindings_page.dart';

/// Application router.
///
/// Every page is a `CustomTransitionPage` built by [_buildTransitionPage],
/// so the entire app shares one motion vocabulary. The shell route is a
/// sidebar + content split, unchanged from before; the only change in this
/// file is the transition itself.
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
          path: '/bluetooth/paired',
          pageBuilder: (context, state) => _buildTransitionPage(
            state,
            const BluetoothPage(section: BluetoothSection.paired),
          ),
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

/// Shared axis X transition for sibling navigation.
///
/// The incoming page fades in quickly, then settles into place with a short,
/// direction-aware slide. Fixed-pixel distance so the motion feels the same
/// on every monitor. The fade completes before the slide, so the page is
/// readable while it moves.
///
/// Direction:
///   - forward (push)  → slides from +24 px to 0 (new page comes from the right)
///   - reverse (pop)   → slides from 0 to +24 px (page leaves to the right)
///
/// The `secondaryAnimation` is intentionally not used. `CustomTransitionPage`
/// in GoRouter swaps the previous route at the route level, so the outgoing
/// page's movement is handled by the shell's swap, not by this builder.
/// Wrapping the incoming child with both `animation` and `secondaryAnimation`
/// (as the old version did) double-animates it.
Page<dynamic> _buildTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Fade: quick rise, fully opaque by 60% of the animation.
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        reverseCurve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      );

      // Slide: eased settle, starts after the fade so the page is visible
      // before it moves.
      final slide = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeInCubic),
      );

      // Direction: forward slides from the right (+24 → 0), reverse slides
      // to the right (0 → +24). This makes back-navigation feel correct
      // instead of always sliding in from the same side.
      final isForward =
          animation.status == AnimationStatus.forward ||
          animation.status == AnimationStatus.completed;
      final direction = isForward ? 1.0 : -1.0;

      final offset = Tween<double>(
        begin: 24.0 * direction,
        end: 0.0,
      ).animate(slide);

      return FadeTransition(
        opacity: fade,
        child: AnimatedBuilder(
          animation: offset,
          child: child,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(offset.value, 0),
              child: child,
            );
          },
        ),
      );
    },
  );
}
