// State of the top-centre notification queue.

import 'package:equatable/equatable.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';

/// Immutable snapshot of the notification queue.
class NotificationState extends Equatable {
  /// Creates a queue state.
  ///
  /// [visible] is ordered newest first. [dismissing] holds ids that are playing
  /// their exit animation and are removed once the animation completes.
  /// [pendingCount] is the number of notifications waiting for a free slot.
  const NotificationState({
    this.visible = const <ShellNotification>[],
    this.dismissing = const <String>{},
    this.pendingCount = 0,
  });

  /// Cards currently on screen, including those animating out.
  final List<ShellNotification> visible;

  /// Ids whose exit animation is in progress.
  final Set<String> dismissing;

  /// Notifications queued beyond the visible limit.
  final int pendingCount;

  /// Whether no cards are on screen.
  bool get isEmpty => visible.isEmpty;

  /// Whether the card with [id] is playing its exit animation.
  bool isDismissing(String id) => dismissing.contains(id);

  /// Returns a copy with the provided fields replaced.
  NotificationState copyWith({
    List<ShellNotification>? visible,
    Set<String>? dismissing,
    int? pendingCount,
  }) {
    return NotificationState(
      visible: visible ?? this.visible,
      dismissing: dismissing ?? this.dismissing,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[visible, dismissing, pendingCount];
}
