import 'dart:async';

import 'package:flutter/material.dart';

/// # Staggered Appear
///
/// Fades and slides a result into place once, with a small delay per position
/// so a fresh search result list ripples in instead of popping.
class StaggeredAppear extends StatefulWidget {
  /// Creates a staggered entrance wrapper.
  ///
  /// # Parameters
  /// - [index]: position in the result list, used to offset the start.
  /// - [child]: tile to reveal.
  const StaggeredAppear({required this.index, required this.child, super.key});

  /// Position in the result list, used to offset the start.
  final int index;

  /// Tile to reveal.
  final Widget child;

  @override
  State<StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<StaggeredAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Step 1: Cap the stagger so long catalogs do not delay later tiles.
    final delay = Duration(milliseconds: widget.index.clamp(0, 12) * 18);
    _timer = Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
