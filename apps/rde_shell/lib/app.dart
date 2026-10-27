// Root widget of the RDE shell.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_shell/core/shell/shell_surface.dart';
import 'package:rde_shell/core/theme/app_theme.dart';
import 'package:rde_shell/features/notifications/data/repositories/demo_notification_repository.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/domain/repositories/notification_repository.dart';
import 'package:rde_shell/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:rde_shell/features/shell/presentation/pages/shell_scaffold.dart';

/// Enables the demo notification feed unless disabled at build time.
///
/// A D-Bus source can replace the demo by passing a [NotificationRepository]
/// into [RdeShellApp]; the presentation layer does not change.
const bool _demoNotificationsEnabled = bool.fromEnvironment(
  'RDE_SHELL_DEMO',
  defaultValue: true,
);

/// Root widget of the desktop shell.
class RdeShellApp extends StatefulWidget {
  /// Creates the shell app.
  ///
  /// [notificationRepository] and [surface] are injectable for tests; both
  /// default to the Wayland/demo implementations.
  const RdeShellApp({super.key, this.notificationRepository, this.surface});

  /// Optional notification source override.
  final NotificationRepository? notificationRepository;

  /// Optional layer-surface controller override.
  final ShellSurface? surface;

  @override
  State<RdeShellApp> createState() => _RdeShellAppState();
}

class _RdeShellAppState extends State<RdeShellApp> {
  late final ShellSurface _surface = widget.surface ?? WaylandShellSurface();
  late final NotificationCubit _notifications = NotificationCubit(
    widget.notificationRepository ?? _defaultRepository(),
  )..start();

  @override
  void dispose() {
    unawaited(_notifications.close());
    super.dispose();
  }

  NotificationRepository _defaultRepository() {
    if (!_demoNotificationsEnabled) {
      return const _EmptyNotificationRepository();
    }
    return const DemoNotificationRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationCubit>.value(
      value: _notifications,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RDE Shell',
        theme: AppTheme.dark(),
        home: ShellScaffold(surface: _surface),
      ),
    );
  }
}

/// Notification source used when the demo feed is disabled.
class _EmptyNotificationRepository implements NotificationRepository {
  const _EmptyNotificationRepository();

  @override
  Stream<ShellNotification> watch() => const Stream<ShellNotification>.empty();
}
