// Demo notification feed used until a real event source is wired up.

import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';

/// Replays a curated set of notifications so the overlay can be evaluated.
///
/// Production will replace this with a D-Bus backed implementation of
/// [NotificationRepository]. Disable the feed with
/// `--dart-define=RDE_SHELL_DEMO=false` once a real source is connected.
class DemoNotificationRepository implements NotificationRepository {
  /// Creates the demo feed.
  ///
  /// [initialDelay] lets the first frame settle before the first card flies in.
  /// [interval] spaces subsequent notifications so the stack can be observed.
  const DemoNotificationRepository({
    this.initialDelay = const Duration(milliseconds: 1100),
    this.interval = const Duration(seconds: 14),
  });

  /// Delay before the first notification.
  final Duration initialDelay;

  /// Delay between following notifications.
  final Duration interval;

  /// Notification scripts, reused in order once the list is exhausted.
  static final List<ShellNotification Function(int)> _script =
      <ShellNotification Function(int)>[
        (int index) => ShellNotification(
          id: 'demo-wifi-connected-$index',
          title: 'Wi-Fi connected',
          message: 'Connected to RDE-Home on the 5 GHz band.',
          severity: NotificationSeverity.network,
        ),
        (int index) => ShellNotification(
          id: 'demo-screenshot-$index',
          title: 'Screenshot saved',
          message: 'Saved to ~/Pictures/Screenshots.',
          severity: NotificationSeverity.success,
          timeout: const Duration(seconds: 5),
        ),
        (int index) => ShellNotification(
          id: 'demo-battery-$index',
          title: 'Battery running low',
          message: '18% remaining. Plug in to keep the session alive.',
          severity: NotificationSeverity.warning,
          timeout: const Duration(seconds: 8),
        ),
        (int index) => ShellNotification(
          id: 'demo-theme-$index',
          title: 'Theme updated',
          message: 'Material 3 Expressive palettes are now active.',
          severity: NotificationSeverity.info,
        ),
        (int index) => ShellNotification(
          id: 'demo-wifi-lost-$index',
          title: 'Wi-Fi disconnected',
          message: 'RDE-Home dropped. Using the wired connection instead.',
          severity: NotificationSeverity.network,
        ),
        (int index) => ShellNotification(
          id: 'demo-backup-$index',
          title: 'Backup failed',
          message: 'The backup drive could not be reached.',
          severity: NotificationSeverity.error,
          timeout: const Duration(seconds: 8),
        ),
      ];

  @override
  Stream<ShellNotification> watch() async* {
    await Future<void>.delayed(initialDelay);

    for (int index = 0; ; index++) {
      yield _script[index % _script.length](index);

      // The first two cards arrive close together to demonstrate stacking.
      final Duration delay = index == 0
          ? const Duration(milliseconds: 850)
          : interval;
      await Future<void>.delayed(delay);
    }
  }
}
