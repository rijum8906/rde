// Top panel of the RDE shell.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rde_shell/core/constants/app_layout.dart';

/// The shell's always-visible top bar.
///
/// It shows the RDE wordmark and a live clock. The bar owns the panel's
/// exclusive zone, so it doubles as the anchor above the notification lane.
class ShellPanel extends StatefulWidget {
  /// Creates the shell panel.
  const ShellPanel({super.key});

  @override
  State<ShellPanel> createState() => _ShellPanelState();
}

class _ShellPanelState extends State<ShellPanel> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final String hour = _now.hour.toString().padLeft(2, '0');
    final String minute = _now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      height: initialPanelHeight.toDouble(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          _BrandMark(scheme: scheme),
          const SizedBox(width: 10),
          Text(
            'RDE',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Shell',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            _timeLabel,
            style: textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small expressive gradient mark next to the wordmark.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.primary,
            scheme.tertiary.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 13,
        color: scheme.onPrimary,
      ),
    );
  }
}
