import 'package:flutter/material.dart';

/// A custom track shape that draws a thick, pill-shaped rail with a gap
/// around the thumb.
class ExpressiveSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const ExpressiveSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final Canvas canvas = context.canvas;
    final double trackHeight = sliderTheme.trackHeight ?? 16.0;
    final double trackRadius = trackHeight / 2;
    final double gap = 4.0;

    final double left = offset.dx;
    final double right = offset.dx + parentBox.size.width;
    final double centerY = offset.dy + (parentBox.size.height / 2);
    final double top = centerY - (trackHeight / 2);
    final double bottom = centerY + (trackHeight / 2);

    // Draw Inactive Track (Right side)
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!;
    if (thumbCenter.dx + gap < right) {
      final RRect inactiveRect = RRect.fromLTRBR(
        thumbCenter.dx + gap,
        top,
        right,
        bottom,
        Radius.circular(trackRadius),
      );
      canvas.drawRRect(inactiveRect, inactivePaint);
    }

    // Draw Active Track (Left side)
    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    if (left < thumbCenter.dx - gap) {
      final RRect activeRect = RRect.fromLTRBR(
        left,
        top,
        thumbCenter.dx - gap,
        bottom,
        Radius.circular(trackRadius),
      );
      canvas.drawRRect(activeRect, activePaint);
    }
  }
}

/// A custom thumb shape that draws a thin vertical pill instead of a circle.
class ExpressiveSliderThumbShape extends SliderComponentShape {
  const ExpressiveSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(3, 22);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()..color = sliderTheme.thumbColor!;

    final RRect thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 3, height: 22),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(thumbRect, paint);
  }
}
