import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rde_shell/core/shell/shell_surface.dart';
import 'package:rde_shell/core/theme/app_theme.dart';
import 'package:rde_shell/features/notifications/domain/entities/notification_severity.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rde_shell/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:rde_shell/features/notifications/presentation/notification_metrics.dart';
import 'package:rde_shell/features/notifications/presentation/widgets/notification_card.dart';
import 'package:rde_shell/features/notifications/presentation/widgets/notification_host.dart';

class _EmptyRepository implements NotificationRepository {
  @override
  Stream<ShellNotification> watch() => const Stream<ShellNotification>.empty();
}

/// Surface that records the lane heights requested by the host.
class _RecordingSurface implements ShellSurface {
  final List<int> heights = <int>[];

  @override
  Future<void> setNotificationLaneHeight(int height) async {
    heights.add(height);
  }
}

Widget _hostHarness({
  required NotificationCubit cubit,
  required ShellSurface surface,
}) {
  return BlocProvider<NotificationCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topCenter,
          child: NotificationHost(surface: surface),
        ),
      ),
    ),
  );
}

const ShellNotification _wifiNotification = ShellNotification(
  id: 'wifi-connected',
  title: 'Wi-Fi connected',
  message: 'Connected to RDE-Home on the 5 GHz band.',
  severity: NotificationSeverity.network,
  timeout: Duration(seconds: 1),
);

void main() {
  testWidgets('renders a card, resizes the surface, then collapses', (
    WidgetTester tester,
  ) async {
    final NotificationCubit cubit = NotificationCubit(_EmptyRepository());
    final _RecordingSurface surface = _RecordingSurface();

    await tester.pumpWidget(_hostHarness(cubit: cubit, surface: surface));
    cubit.show(_wifiNotification);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Wi-Fi connected'), findsOneWidget);
    expect(find.textContaining('RDE-Home'), findsOneWidget);
    expect(
      surface.heights,
      contains(NotificationMetrics.laneHeight(visible: 1, pending: 0).round()),
    );

    // The life bar completes after 1s, the card exits, then the lane collapses.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Wi-Fi connected'), findsNothing);
    expect(surface.heights.last, 0);
  });

  testWidgets('tapping a card dismisses it before the timeout', (
    WidgetTester tester,
  ) async {
    final NotificationCubit cubit = NotificationCubit(_EmptyRepository());

    await tester.pumpWidget(
      _hostHarness(cubit: cubit, surface: _RecordingSurface()),
    );
    cubit.show(_wifiNotification);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(NotificationCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Wi-Fi connected'), findsNothing);
    expect(cubit.state.visible, isEmpty);
  });

  testWidgets('shows the overflow chip when the queue is full', (
    WidgetTester tester,
  ) async {
    final NotificationCubit cubit = NotificationCubit(_EmptyRepository());

    await tester.pumpWidget(
      _hostHarness(cubit: cubit, surface: _RecordingSurface()),
    );

    for (int index = 0; index <= NotificationMetrics.maxVisible; index++) {
      cubit.show(
        ShellNotification(
          id: 'notification-$index',
          title: 'Title $index',
          message: 'Message $index',
          timeout: const Duration(minutes: 1),
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('1 more notification'), findsOneWidget);

    // Unmount so the pending tickers are disposed before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
}
