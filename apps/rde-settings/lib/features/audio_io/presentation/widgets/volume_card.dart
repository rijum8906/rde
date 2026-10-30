import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_state.dart';

/// Master output volume, backed by the `org.rde.Volume` service.
///
/// The slider is the page's one continuous control, so it carries the Material
/// 3 expressive treatment: a thick rail whose filled part ripples, a large
/// thumb, and a value pill that changes tint with the mute state. The service
/// owns the mixer, so every control here writes through it.
class VolumeCard extends StatelessWidget {
  const VolumeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<VolumeBloc>().state;
    final master = state.master;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  (master?.muted ?? false) ? Icons.volume_off : Icons.volume_up,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Master Volume',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (master != null)
                  _ValuePill(volume: master.volume, muted: master.muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Applies to every output. The RDE volume service writes the '
              'change to the hardware mixer.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (master == null)
              Text(
                state.status == VolumeStatus.loading
                    ? 'Reading the master volume…'
                    : 'The volume service (org.rde.Volume) is not running.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              _VolumeControls(
                master: master,
                isBusy: state.isBusy,
                isReady: state.status == VolumeStatus.success,
              ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: state.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Percentage pill next to the title. Muted is a state, not a number, so the
/// tint and the glyph carry it instead of the text.
class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.volume, required this.muted});

  final int volume;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted) ...[
            Icon(
              Icons.volume_off,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            '$volume%',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: muted
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeControls extends StatelessWidget {
  const _VolumeControls({
    required this.master,
    required this.isBusy,
    required this.isReady,
  });

  final MasterVolume master;
  final bool isBusy;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bloc = context.read<VolumeBloc>();

    final min = master.minVolume.toDouble();
    final max = master.maxVolume.toDouble();
    final value = master.volume.toDouble().clamp(min, max);
    final lower = (master.volume - master.step)
        .clamp(master.minVolume, master.maxVolume)
        .toInt();
    final raise = (master.volume + master.step)
        .clamp(master.minVolume, master.maxVolume)
        .toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 16,
            trackShape: const _ExpressiveWaveTrackShape(),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
            disabledActiveTrackColor: colorScheme.surfaceContainerHighest,
            disabledInactiveTrackColor: colorScheme.surfaceContainerHighest,
            disabledThumbColor: colorScheme.outlineVariant,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: master.hasRange ? (master.maxVolume - master.minVolume) : null,
            label: '${master.volume}%',
            onChanged: isReady
                ? (next) =>
                      bloc.add(VolumeSliderChangedEvent(next.round()))
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: master.muted ? 'Unmute' : 'Mute',
              onPressed: isReady && !isBusy
                  ? () => bloc.add(const ToggleVolumeMuteEvent())
                  : null,
              icon: Icon(master.muted ? Icons.volume_up : Icons.volume_off),
            ),
            const Spacer(),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: RdeLoadingIndicator(size: 18),
              ),
            IconButton.filledTonal(
              tooltip: 'Lower by ${master.step}%',
              onPressed: isReady
                  ? () => bloc.add(VolumeSetEvent(lower))
                  : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Raise by ${master.step}%',
              onPressed: isReady
                  ? () => bloc.add(VolumeSetEvent(raise))
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Material 3 expressive slider track.
///
/// The inactive rail stays a flat rounded band, and the active part is drawn as
/// a wave that settles into the thumb, so the filled side reads as energy
/// leaving for the output. Drawing it as a stroked sine keeps the ends rounded
/// at any volume.
class _ExpressiveWaveTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _ExpressiveWaveTrackShape();

  /// How far the wave rises above and below the rail, in logical pixels.
  static const double _amplitude = 3.0;

  /// Distance between two crests of the wave.
  static const double _wavelength = 16.0;

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
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final canvas = context.canvas;
    final centerY = rect.center.dy;
    final radius = Radius.circular(rect.height / 2);

    // Step 1: The inactive rail is the whole track, flat.
    final inactiveColor = isEnabled
        ? sliderTheme.inactiveTrackColor
        : sliderTheme.disabledInactiveTrackColor;
    if (inactiveColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = inactiveColor,
      );
    }

    // Step 2: The active rail is a wave from the leading edge to the thumb.
    final activeColor = isEnabled
        ? sliderTheme.activeTrackColor
        : sliderTheme.disabledActiveTrackColor;
    if (activeColor == null) {
      return;
    }

    final leading = textDirection == TextDirection.ltr
        ? rect.left
        : rect.right;
    final direction = thumbCenter.dx >= leading ? 1.0 : -1.0;
    final length = (thumbCenter.dx - leading).abs();
    if (length < 0.5) {
      return;
    }

    final wave = Path()..moveTo(leading, centerY);
    for (double step = 0; step <= length; step += 1) {
      final x = leading + direction * step;
      final y =
          centerY +
          _amplitude * math.sin(step / _wavelength * 2 * math.pi);
      wave.lineTo(x, y);
    }
    wave.lineTo(thumbCenter.dx, centerY);

    canvas.drawPath(
      wave,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.height
        ..strokeCap = StrokeCap.round,
    );
  }
}
