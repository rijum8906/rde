import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/expressive_slider_shape.dart';

/// A Material 3 Expressive volume slider that supports mouse wheel scrolling.
class ScrollableVolumeSlider extends StatelessWidget {
  const ScrollableVolumeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.isEnabled = true,
  });

  /// Share of the range one wheel notch moves.
  ///
  /// 5% of a 0-100 volume is the step the volume service itself uses for its
  /// shortcuts, and a whole-number step is what makes a notch feel responsive:
  /// moving one percent per notch read as stuck.
  static const double _wheelStepFraction = 0.05;

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

        // Scroll up = increase, scroll down = decrease. A horizontal wheel is
        // not this slider's business.
        final delta = pointerSignal.scrollDelta.dy;
        if (delta == 0) return;

        // The step never falls below one division, so a discrete slider lands
        // on a step instead of creeping past the value it draws.
        final division = divisions != null
            ? (max - min) / divisions!
            : (max - min) / 20;
        final step = math.max((max - min) * _wheelStepFraction, division);
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
            trackShape: const ExpressiveSliderTrackShape(),
            thumbShape: const ExpressiveSliderThumbShape(),
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
