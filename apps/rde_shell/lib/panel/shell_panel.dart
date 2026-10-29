//! # Shell Panel
//!
//! The single top bar of the RDE desktop shell: brand mark, session label,
//! status icons and a clock.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rde_shell/core/constants/app_layout.dart';

/// The shell's always-visible top panel.
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

    // Tick once a second so the minute label stays current without rebuilding
    // anything outside the panel.
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
      height: panelHeight.toDouble(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          const _BrandMark(),
          const SizedBox(width: 10),
          Text(
            'RDE',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 10),
          _StatusDot(color: scheme.primary),
          const SizedBox(width: 10),
          Text(
            'Desktop',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.wifi_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Icon(
            Icons.volume_up_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Icon(
            Icons.battery_full_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
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

/// Small gradient square that stands in for the RDE logo.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
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
        size: 12,
        color: scheme.onPrimary,
      ),
    );
  }
}

/// Small round separators used between the panel's text labels.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }
}
