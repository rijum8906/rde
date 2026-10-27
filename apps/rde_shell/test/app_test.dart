import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_shell/app.dart';
import 'package:rde_shell/core/shell/shell_surface.dart';
import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';

class _PushRepository implements NotificationRepository {
  final StreamController<ShellNotification> controller =
      StreamController<ShellNotification>.broadcast();

  @override
  Stream<ShellNotification> watch() => controller.stream;
}

void main() {
  testWidgets('renders the panel and presents notifications from the source', (
    WidgetTester tester,
  ) async {
    final _PushRepository repository = _PushRepository();

    await tester.pumpWidget(
      RdeShellApp(
        notificationRepository: repository,
        surface: const NoopShellSurface(),
      ),
    );
    await tester.pump();

    expect(find.text('RDE'), findsOneWidget);
    expect(find.text('Shell'), findsOneWidget);

    repository.controller.add(
      const ShellNotification(
        id: 'app-test',
        title: 'Notification from source',
        message: 'The shell presents whatever the repository emits.',
        severity: NotificationSeverity.info,
        timeout: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Notification from source'), findsOneWidget);

    // Unmount to dispose the panel clock and the notification tickers.
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.controller.close();
  });
}
