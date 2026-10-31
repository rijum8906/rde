import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A Material 3 Expressive slider with a thick pill track, a thin vertical thumb,
/// and support for mouse wheel scrolling.
class RdeSlider extends StatelessWidget {
  const RdeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.isEnabled = true,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final int? divisions;
  final String? label;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (!isEnabled || onChanged == null) return;
        if (pointerSignal is! PointerScrollEvent) return;

        // Scroll up = increase, scroll down = decrease.
        final delta = pointerSignal.scrollDelta.dy;
        if (delta == 0) return;

        // Calculate step based on divisions, or fallback to 5%
        final division = divisions != null
            ? (max - min) / divisions!
            : (max - min) / 20;
        final step = math.max((max - min) * 0.05, division);

        final direction = delta < 0 ? 1.0 : -1.0;
        final newValue = (value + direction * step).clamp(min, max);

        if (newValue != value) {
          onChanged!(newValue);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 16,
            trackShape: const _ExpressiveSliderTrackShape(),
            thumbShape: const _ExpressiveSliderThumbShape(),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            disabledActiveTrackColor: colorScheme.surfaceContainerHighest,
            disabledInactiveTrackColor: colorScheme.surfaceContainerHighest,
            disabledThumbColor: colorScheme.outlineVariant,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: isEnabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}

/// A custom track shape that draws a thick, pill-shaped rail with a gap
/// around the thumb.
class _ExpressiveSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _ExpressiveSliderTrackShape();

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
class _ExpressiveSliderThumbShape extends SliderComponentShape {
  const _ExpressiveSliderThumbShape();

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
