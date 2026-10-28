import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Android-style curvy progress bar.
///
/// The played portion is drawn as a smooth sine wave; the unplayed portion is
/// a flat line at the same vertical center. A thin white line caps the
/// transition, matching the Material 3 media-player look. The wave is
/// deterministic (no randomness), so the shape doesn't jitter between frames.
class CurvyProgress extends StatelessWidget {
  const CurvyProgress({
    super.key,
    required this.position,
    required this.length,
    required this.isPlaying,
    required this.color,
    required this.trackColor,
    this.height = 24,
    this.waveAmplitude = 2.5,
    this.wavelength = 40.0,
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

    final playedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final restPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Unplayed portion: a flat line from the playhead to the end.
    if (playedWidth < size.width) {
      canvas.drawLine(
        Offset(playedWidth, centerY),
        Offset(size.width, centerY),
        restPaint,
      );
    }

    // Played portion: a smooth sine wave, phase-aligned so the curve starts
    // at the left edge and ends at the playhead with the wave at its
    // natural vertical position (no visible jump at either end).
    if (playedWidth > 0) {
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
    }

    // Playhead: a small filled dot where the wave meets the flat line, so
    // the transition reads as "here" rather than as an abrupt color change.
    if (fraction > 0 && fraction < 1) {
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        strokeWidth * 0.9,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvyPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor;
}
