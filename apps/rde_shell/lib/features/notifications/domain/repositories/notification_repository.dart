// Source of notifications presented by the shell.

import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';

/// Produces the stream of notifications the shell should display.
///
/// The shell is transport agnostic: the current implementation is an in-process
/// demo feed, and a D-Bus source (`org.rde.Notification` or Wi-Fi events from
/// `org.rde.Wifi`) can implement this interface later without touching the
/// presentation layer.
abstract interface class NotificationRepository {
  /// Returns the notifications to show.
  ///
  /// Implementations must return a broadcast stream that can be listened to
  /// once for the lifetime of the shell.
  Stream<ShellNotification> watch();
}
