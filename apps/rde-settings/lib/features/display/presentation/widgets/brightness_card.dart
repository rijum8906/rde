import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_bloc.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_state.dart';

class BrightnessCard extends StatelessWidget {
  const BrightnessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<BrightnessBloc>().state;
    final level = state.level;

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brightness',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Adjust the backlight of the active display',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (level != null)
                  Text(
                    'v${level.version}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // Content
            if (level == null)
              Text(
                state.status == BrightnessStatus.loading
                    ? 'Reading the display brightness…'
                    : 'The brightness service is not running.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              _BrightnessControls(
                level: level,
                isBusy: state.isBusy,
                isReady: state.canChange,
              ),

            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineError(message: state.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrightnessControls extends StatelessWidget {
  const _BrightnessControls({
    required this.level,
    required this.isBusy,
    required this.isReady,
  });

  final BrightnessLevel level;
  final bool isBusy;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BrightnessBloc>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final percent = level.percent.clamp(0, 100);
    final canChange = isReady && !isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Step down through DecreaseBrightness.
            IconButton.filledTonal(
              tooltip: 'Dim',
              onPressed: canChange
                  ? () => bloc.add(const BrightnessDecreaseEvent(10))
                  : null,
              icon: const Icon(Icons.remove_rounded, size: 22),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: RdeSlider(
                value: percent.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$percent%',
                isEnabled: isReady,
                onChanged: (value) {
                  bloc.add(BrightnessSliderChangedEvent(value.round()));
                },
              ),
            ),
            const SizedBox(width: 12),

            // Step up through IncreaseBrightness.
            IconButton.filledTonal(
              tooltip: 'Brighten',
              onPressed: canChange
                  ? () => bloc.add(const BrightnessIncreaseEvent(10))
                  : null,
              icon: const Icon(Icons.add_rounded, size: 22),
            ),

            const SizedBox(width: 16),

            // Loading / Percentage text
            SizedBox(
              width: 50,
              child: isBusy
                  ? const Center(child: RdeLoadingIndicator(size: 18))
                  : Text(
                      '$percent%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
            ),
          ],
        ),
        if (level.hasRange) ...[
          const SizedBox(height: 8),
          Text(
            'Raw ${level.raw} of ${level.max}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
