// Animated notification card shown in the top-centre shell lane.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rde_shell/core/theme/shell_motion.dart';
import 'package:rde_shell/features/notifications/domain/entities/shell_notification.dart';
import 'package:rde_shell/features/notifications/presentation/notification_metrics.dart';
import 'package:rde_shell/features/notifications/presentation/widgets/notification_visuals.dart';

/// Material 3 Expressive card for a single notification.
///
/// The card owns three behaviours that must stay in lock-step with its
/// animation:
/// - a springy entrance that slides it down from behind the panel,
/// - a life bar that mirrors the remaining display time,
/// - an exit that runs before the cubit is told the slot is free.
///
/// Hovering pauses the life bar, a tap or upward drag dismisses early, and the
/// close affordance appears on hover.
class NotificationCard extends StatefulWidget {
  /// Creates a notification card.
  const NotificationCard({
    required this.notification,
    required this.exiting,
    required this.onExitRequested,
    required this.onExitCompleted,
    super.key,
  });

  /// Notification rendered by this card.
  final ShellNotification notification;

  /// Whether the queue has asked this card to leave.
  final bool exiting;

  /// Called when the card should start its exit (timeout, tap, drag, close).
  final VoidCallback onExitRequested;

  /// Called once the exit animation finished and the slot can be released.
  final VoidCallback onExitCompleted;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ShellMotion.cardEntry,
  );

  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: widget.notification.timeout,
  );

  bool _hovered = false;
  bool _dismissing = false;
  bool _reduceMotion = false;
  bool _didInit = false;
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _life.addStatusListener(_handleLifeStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }
    _didInit = true;

    // Respect the desktop's reduced-motion preference: skip the spring and
    // short-circuit the life bar into place.
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
    _life.forward();
  }

  @override
  void didUpdateWidget(covariant NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !_dismissing) {
      unawaited(_playExit());
    }
  }

  void _handleLifeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_dismissing) {
      widget.onExitRequested();
    }
  }

  Future<void> _playExit() async {
    _dismissing = true;
    _life.stop();

    await _entrance.animateBack(
      0,
      duration: _reduceMotion
          ? const Duration(milliseconds: 90)
          : ShellMotion.cardExit,
      curve: ShellMotion.exitCurve,
    );

    if (mounted) {
      widget.onExitCompleted();
    }
  }

  void _requestExit() {
    if (_dismissing) {
      return;
    }
    widget.onExitRequested();
  }

  void _setHovered(bool hovered) {
    setState(() => _hovered = hovered);
    if (_dismissing) {
      return;
    }
    if (hovered) {
      _life.stop();
    } else {
      _life.forward();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) {
      return;
    }
    setState(() {
      _dragging = true;
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-180.0, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) {
      return;
    }

    final bool shouldDismiss =
        _dragOffset < -56 || (details.velocity.pixelsPerSecond.dy < -700);
    if (shouldDismiss) {
      _requestExit();
      return;
    }

    // Spring back when the gesture was not decisive.
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
  }

  @override
  void dispose() {
    _life.removeStatusListener(_handleLifeStatus);
    _entrance.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final NotificationVisuals visuals = NotificationVisuals.of(
      widget.notification.severity,
      scheme,
    );

    final Animation<double> fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0, -1.8), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0, 0.85, curve: ShellMotion.entryCurve),
          ),
        );
    final Animation<double> scale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0, 0.85, curve: ShellMotion.entryCurve),
      ),
    );
    final Animation<double> iconScale = Tween<double>(begin: 0.4, end: 1)
        .animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.18, 0.95, curve: ShellMotion.entryCurve),
          ),
        );

    final double dragOpacity = (1 - (-_dragOffset / 240)).clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      container: true,
      label: '${widget.notification.title}. ${widget.notification.message}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestExit,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.topCenter,
                child: AnimatedContainer(
                  duration: _dragging ? Duration.zero : ShellMotion.hover,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, _dragOffset, 0),
                  child: Opacity(
                    opacity: dragOpacity,
                    child: AnimatedScale(
                      scale: _hovered ? 1.012 : 1,
                      duration: ShellMotion.hover,
                      curve: Curves.easeOutCubic,
                      child: _CardSurface(
                        notification: widget.notification,
                        visuals: visuals,
                        scheme: scheme,
                        textTheme: theme.textTheme,
                        iconScale: iconScale,
                        life: _life,
                        hovered: _hovered,
                        onClose: _requestExit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painted surface of the notification card.
class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.notification,
    required this.visuals,
    required this.scheme,
    required this.textTheme,
    required this.iconScale,
    required this.life,
    required this.hovered,
    required this.onClose,
  });

  final ShellNotification notification;
  final NotificationVisuals visuals;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final Animation<double> iconScale;
  final Animation<double> life;
  final bool hovered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: NotificationMetrics.cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              visuals.accent.withValues(alpha: 0.10),
              scheme.surfaceContainerHighest.withValues(alpha: 0.97),
            ),
            scheme.surfaceContainerHigh.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(
          color: Color.alphaBlend(
            visuals.accent.withValues(alpha: 0.22),
            scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: visuals.accent.withValues(alpha: 0.10),
            blurRadius: 42,
            spreadRadius: -10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 16),
              child: Row(
                children: <Widget>[
                  ScaleTransition(
                    scale: iconScale,
                    child: _IconBadge(
                      icon: visuals.icon,
                      accent: visuals.accent,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _CloseButton(visible: hovered, onPressed: onClose),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 7,
            height: 3,
            child: _LifeBar(life: life, accent: visuals.accent),
          ),
        ],
      ),
    );
  }
}

/// Tonal icon badge with a soft inner highlight.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: 22, color: accent),
    );
  }
}

/// Close affordance revealed on hover.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: ShellMotion.hover,
        curve: Curves.easeOutCubic,
        child: Tooltip(
          message: 'Dismiss',
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Countdown bar showing how long the card will remain visible.
class _LifeBar extends StatelessWidget {
  const _LifeBar({required this.life, required this.accent});

  final Animation<double> life;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: scheme.onSurface.withValues(alpha: 0.07),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: AnimatedBuilder(
          animation: life,
          builder: (BuildContext context, Widget? child) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: life.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.95),
                      accent.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
