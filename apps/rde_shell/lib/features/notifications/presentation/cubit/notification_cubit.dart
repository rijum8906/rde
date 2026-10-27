// Owns the notification queue and its dismissal lifecycle.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rde_shell/features/notifications/presentation/notification_metrics.dart';
import 'package:rde_shell/features/notifications/presentation/state/notification_state.dart';

/// Queues notifications and coordinates their exit animations.
///
/// The cubit owns ordering and overflow. Timers live inside each card so the
/// progress animation and the auto-dismiss deadline cannot drift apart. A card
/// asks the cubit to dismiss, plays its exit animation, then reports completion
/// back here so a pending notification can take its slot.
class NotificationCubit extends Cubit<NotificationState> {
  /// Creates a cubit that feeds from [repository].
  NotificationCubit(this._repository) : super(const NotificationState());

  final NotificationRepository _repository;
  final Queue<ShellNotification> _pending = Queue<ShellNotification>();
  StreamSubscription<ShellNotification>? _subscription;

  /// Starts listening to the repository.
  ///
  /// Safe to call more than once; only the first call subscribes.
  void start() {
    _subscription ??= _repository.watch().listen(
      show,
      onError: (Object error) {
        debugPrint('NotificationCubit: notification source failed: $error');
      },
    );
  }

  /// Adds [notification] to the queue.
  ///
  /// Duplicates with the same id are ignored. When the visible slots are full
  /// the notification waits in the pending queue and is promoted automatically.
  void show(ShellNotification notification) {
    final bool alreadyTracked =
        state.visible.any((item) => item.id == notification.id) ||
        _pending.any((item) => item.id == notification.id);
    if (alreadyTracked) {
      return;
    }

    if (state.visible.length >= NotificationMetrics.maxVisible) {
      _pending.add(notification);
      emit(state.copyWith(pendingCount: _pending.length));
      return;
    }

    emit(
      state.copyWith(
        visible: <ShellNotification>[notification, ...state.visible],
      ),
    );
  }

  /// Marks the card with [id] as exiting.
  ///
  /// The card keeps its slot until [completeDismiss] is called so the exit
  /// animation is not clipped by an immediate rebuild.
  void beginDismiss(String id) {
    final bool isVisible = state.visible.any((item) => item.id == id);
    if (!isVisible || state.dismissing.contains(id)) {
      return;
    }

    emit(state.copyWith(dismissing: <String>{...state.dismissing, id}));
  }

  /// Removes a dismissed card and promotes the next pending notification.
  void completeDismiss(String id) {
    final List<ShellNotification> visible = state.visible
        .where((item) => item.id != id)
        .toList(growable: true);
    final Set<String> dismissing = <String>{...state.dismissing}..remove(id);

    // Fill the freed slot from the overflow queue, oldest first.
    while (_pending.isNotEmpty &&
        visible.length < NotificationMetrics.maxVisible) {
      visible.add(_pending.removeFirst());
    }

    emit(
      NotificationState(
        visible: visible,
        dismissing: dismissing,
        pendingCount: _pending.length,
      ),
    );
  }

  /// Starts dismissing every visible card.
  void dismissAll() {
    for (final ShellNotification notification in state.visible) {
      beginDismiss(notification.id);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
