import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rde_shell/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:rde_shell/features/notifications/presentation/notification_metrics.dart';

/// Repository driven manually by the tests.
class _FakeRepository implements NotificationRepository {
  final StreamController<ShellNotification> controller =
      StreamController<ShellNotification>.broadcast();

  @override
  Stream<ShellNotification> watch() => controller.stream;
}

ShellNotification _notification(int index) {
  return ShellNotification(
    id: 'notification-$index',
    title: 'Title $index',
    message: 'Message $index',
    severity: NotificationSeverity.info,
  );
}

void main() {
  late _FakeRepository repository;
  late NotificationCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = NotificationCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.controller.close();
  });

  test('shows the newest notification first', () {
    cubit.show(_notification(0));
    cubit.show(_notification(1));

    expect(cubit.state.visible.first.id, 'notification-1');
    expect(cubit.state.visible.length, 2);
  });

  test('queues notifications beyond the visible limit', () {
    for (int index = 0; index <= NotificationMetrics.maxVisible; index++) {
      cubit.show(_notification(index));
    }

    expect(cubit.state.visible.length, NotificationMetrics.maxVisible);
    expect(cubit.state.pendingCount, 1);
  });

  test('ignores duplicate ids', () {
    cubit.show(_notification(0));
    cubit.show(_notification(0));

    expect(cubit.state.visible.length, 1);
    expect(cubit.state.pendingCount, 0);
  });

  test('promotes a pending notification after a dismissal completes', () {
    for (int index = 0; index <= NotificationMetrics.maxVisible; index++) {
      cubit.show(_notification(index));
    }

    final String dismissed = cubit.state.visible.last.id;
    cubit.beginDismiss(dismissed);
    expect(cubit.state.isDismissing(dismissed), isTrue);

    cubit.completeDismiss(dismissed);

    expect(cubit.state.isDismissing(dismissed), isFalse);
    expect(cubit.state.visible.length, NotificationMetrics.maxVisible);
    expect(cubit.state.pendingCount, 0);
    expect(
      cubit.state.visible.map((ShellNotification item) => item.id),
      contains('notification-3'),
      reason: 'the oldest queued notification takes the freed slot',
    );
  });

  test('keeps a card in state until its exit completes', () {
    cubit.show(_notification(0));
    cubit.beginDismiss('notification-0');

    expect(
      cubit.state.visible.length,
      1,
      reason: 'exit animation needs a slot',
    );
    expect(cubit.state.isDismissing('notification-0'), isTrue);

    cubit.completeDismiss('notification-0');

    expect(cubit.state.visible, isEmpty);
  });

  test('dismissAll requests an exit for every visible card', () {
    cubit.show(_notification(0));
    cubit.show(_notification(1));

    cubit.dismissAll();

    expect(cubit.state.dismissing.length, 2);
  });

  test('feeds notifications from the repository stream', () async {
    cubit.start();
    repository.controller.add(_notification(7));
    await pumpEventQueue();

    expect(cubit.state.visible.single.id, 'notification-7');
  });
}
