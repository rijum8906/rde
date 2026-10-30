import 'dart:math' as math;

import 'package:flutter/material.dart';

class CurvyProgress extends StatelessWidget {
  const CurvyProgress({
    super.key,
    required this.position,
    required this.length,
    required this.color,
    required this.trackColor,
    this.height = 24,
    this.waveAmplitude = 2.5,
    this.wavelength = 18.0,
    this.strokeWidth = 2.5,
  });

  final Duration position;
  final Duration length;
  final Color color;
  final Color trackColor;
  final double height;
  final double waveAmplitude;
  final double wavelength;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final fraction = length.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CurvyPainter(
          fraction: fraction,
          color: color,
          trackColor: trackColor,
          waveAmplitude: waveAmplitude,
          wavelength: wavelength,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CurvyPainter extends CustomPainter {
  _CurvyPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.waveAmplitude,
    required this.wavelength,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double waveAmplitude;
  final double wavelength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final playedWidth = size.width * fraction;

    // 1. Draw the faint background track first (the full width)
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

    // 2. Draw the wavy line on top of it
    if (playedWidth > 0) {
      final playedPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final steps = math.max(2, (playedWidth / 2).ceil());

      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = t * playedWidth;
        final y =
            centerY + math.sin(x / wavelength * 2 * math.pi) * waveAmplitude;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, playedPaint);

      // 3. Add the solid circle at the end of the played wave
      if (fraction > 0 && fraction < 1) {
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        // Slightly larger than the stroke so it pops
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
      old.color != color ||
      old.trackColor != trackColor;
}
