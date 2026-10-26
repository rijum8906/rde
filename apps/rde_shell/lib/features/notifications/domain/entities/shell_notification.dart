// Immutable notification model displayed by the shell overlay.

import 'package:equatable/equatable.dart';
import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';

/// A notification waiting to be shown in the shell overlay.
///
/// Instances are immutable and compared by value so the queue can safely skip
/// duplicates that share an [id].
class ShellNotification extends Equatable {
  /// Creates a notification.
  ///
  /// [id] must be unique per event; use a counter or the originating service's
  /// identifier. [timeout] controls how long the card stays on screen before it
  /// dismisses itself; hovering or focusing the card pauses that timer.
  const ShellNotification({
    required this.id,
    required this.title,
    required this.message,
    this.severity = NotificationSeverity.info,
    this.timeout = const Duration(seconds: 6),
  });

  /// Stable identifier used for de-duplication and dismissal.
  final String id;

  /// Short headline, ideally under 40 characters.
  final String title;

  /// Supporting sentence or two.
  final String message;

  /// Visual severity of the event.
  final NotificationSeverity severity;

  /// How long the card stays visible when not hovered.
  final Duration timeout;

  @override
  List<Object?> get props => <Object?>[id, title, message, severity, timeout];
}
