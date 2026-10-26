// Hosts the top-centre notification lane.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_shell/core/shell/shell_surface.dart';
import 'package:rde_shell/core/theme/shell_motion.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:rde_shell/features/notifications/presentation/notification_metrics.dart';
import 'package:rde_shell/features/notifications/presentation/state/notification_state.dart';
import 'package:rde_shell/features/notifications/presentation/widgets/notification_card.dart';

/// Renders the notification stack and keeps the layer surface in sync.
///
/// The lane grows the Wayland surface downwards as cards arrive and collapses
/// it once the last card finishes its exit. Cards are laid out with
/// [AnimatedPositioned] so inserting or removing one makes the others glide
/// instead of jumping.
class NotificationHost extends StatelessWidget {
  /// Creates a notification host.
  const NotificationHost({required this.surface, super.key});

  /// Surface controller used to grow and shrink the shell.
  final ShellSurface surface;

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationCubit, NotificationState>(
      listenWhen: (NotificationState previous, NotificationState current) =>
          previous.visible.length != current.visible.length ||
          previous.pendingCount != current.pendingCount,
      listener: (BuildContext context, NotificationState state) {
        unawaited(
          surface.setNotificationLaneHeight(_laneHeight(state).round()),
        );
      },
      child: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (BuildContext context, NotificationState state) {
          if (state.visible.isEmpty) {
            return const SizedBox.shrink();
          }

          return IgnorePointer(
            ignoring: state.visible.isEmpty,
            child: SizedBox(
              height: _laneHeight(state),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  for (int index = 0; index < state.visible.length; index++)
                    AnimatedPositioned(
                      key: ValueKey<String>('slot-${state.visible[index].id}'),
                      duration: ShellMotion.stackReflow,
                      curve: ShellMotion.stackCurve,
                      top: _cardTop(index),
                      left: NotificationMetrics.horizontalMargin,
                      right: NotificationMetrics.horizontalMargin,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: NotificationMetrics.maxCardWidth,
                          ),
                          child: _StackedCard(
                            index: index,
                            child: _card(context, state.visible[index], state),
                          ),
                        ),
                      ),
                    ),
                  if (state.pendingCount > 0)
                    AnimatedPositioned(
                      duration: ShellMotion.stackReflow,
                      curve: ShellMotion.stackCurve,
                      top: _moreChipTop(state),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _MoreChip(count: state.pendingCount),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(
    BuildContext context,
    ShellNotification notification,
    NotificationState state,
  ) {
    final NotificationCubit cubit = context.read<NotificationCubit>();

    return NotificationCard(
      key: ValueKey<String>(notification.id),
      notification: notification,
      exiting: state.isDismissing(notification.id),
      onExitRequested: () => cubit.beginDismiss(notification.id),
      onExitCompleted: () => cubit.completeDismiss(notification.id),
    );
  }

  double _cardTop(int index) {
    return NotificationMetrics.laneTopPadding +
        index * (NotificationMetrics.cardHeight + NotificationMetrics.cardGap);
  }

  double _moreChipTop(NotificationState state) {
    return _cardTop(state.visible.length) -
        NotificationMetrics.cardGap +
        NotificationMetrics.moreChipGap;
  }

  double _laneHeight(NotificationState state) {
    return NotificationMetrics.laneHeight(
      visible: state.visible.length,
      pending: state.pendingCount,
    );
  }
}

/// Applies depth styling so cards behind the newest one recede.
class _StackedCard extends StatelessWidget {
  const _StackedCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double scale = switch (index) {
      0 => 1.0,
      1 => 0.975,
      _ => 0.95,
    };
    final double opacity = switch (index) {
      0 => 1.0,
      1 => 0.85,
      _ => 0.68,
    };

    return AnimatedScale(
      scale: scale,
      duration: ShellMotion.stackReflow,
      curve: ShellMotion.stackCurve,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: ShellMotion.stackReflow,
        curve: ShellMotion.stackCurve,
        child: child,
      ),
    );
  }
}

/// Compact indicator for notifications waiting behind the visible cards.
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      height: NotificationMetrics.moreChipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          NotificationMetrics.moreChipHeight / 2,
        ),
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.stacked_line_chart_rounded,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$count more notification${count == 1 ? '' : 's'}',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
