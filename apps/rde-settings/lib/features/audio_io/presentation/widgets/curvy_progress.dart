import 'dart:math' as math;

import 'package:flutter/material.dart';

class CurvyProgress extends StatefulWidget {
  const CurvyProgress({
    super.key,
    required this.position,
    required this.length,
    required this.isPlaying, // New parameter
    required this.color,
    required this.trackColor,
    this.height = 24,
    this.waveAmplitude = 2.5,
    this.wavelength = 18.0,
    this.strokeWidth = 2.5,
  });

  final Duration position;
  final Duration length;
  final bool isPlaying;
  final Color color;
  final Color trackColor;
  final double height;
  final double waveAmplitude;
  final double wavelength;
  final double strokeWidth;

  @override
  State<CurvyProgress> createState() => _CurvyProgressState();
}

class _CurvyProgressState extends State<CurvyProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(CurvyProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = widget.length.inMilliseconds == 0
        ? 0.0
        : (widget.position.inMilliseconds / widget.length.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CurvyPainter(
              fraction: fraction,
              phase: _controller.value,
              color: widget.color,
              trackColor: widget.trackColor,
              waveAmplitude: widget.waveAmplitude,
              wavelength: widget.wavelength,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _CurvyPainter extends CustomPainter {
  _CurvyPainter({
    required this.fraction,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.waveAmplitude,
    required this.wavelength,
    required this.strokeWidth,
  });

  final double fraction;
  final double phase;
  final Color color;
  final Color trackColor;
  final double waveAmplitude;
  final double wavelength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final playedWidth = size.width * fraction;

    // 1. Draw the faint background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      trackPaint,
    );

    // 2. Draw the moving wavy line
    if (playedWidth > 0) {
      final playedPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final steps = math.max(2, (playedWidth / 2).ceil());
      final phaseOffset = phase * 2 * math.pi;

      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = t * playedWidth;
        final y =
            centerY +
            math.sin((x / wavelength * 2 * math.pi) - phaseOffset) *
                waveAmplitude;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, playedPaint);

      // 3. Add the solid dot at the end of the played wave
      if (fraction > 0 && fraction < 1) {
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(playedWidth, centerY),
          strokeWidth * 1.4,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvyPainter old) =>
      old.fraction != fraction ||
      old.phase != phase ||
      old.color != color ||
      old.trackColor != trackColor;
}
