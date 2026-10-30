import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_state.dart';

import 'scrollable_volume_slider.dart';

class VolumeCard extends StatelessWidget {
  const VolumeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<VolumeBloc>().state;
    final master = state.master;
    final devices = context.watch<AudioDevicesBloc>().state.devices;
    final outputs = devices?.outputs ?? const <AudioOutput>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Master Output',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Adjust system volume and output device',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (outputs.isNotEmpty) _OutputPicker(outputs: outputs),
            ],
          ),
          const SizedBox(height: 32),

          // Content
          if (master == null)
            Text(
              state.status == VolumeStatus.loading
                  ? 'Reading the master volume…'
                  : 'The volume service is not running.',
              style: theme.textTheme.bodyMedium?.copyWith(
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
            const SizedBox(height: 16),
            _InlineError(message: state.errorMessage!),
          ],
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
    final bloc = context.read<VolumeBloc>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final min = master.minVolume.toDouble();
    final max = master.maxVolume.toDouble();
    final value = master.volume.toDouble().clamp(min, max);

    // Determine which icon to show based on mute state and volume level
    IconData volumeIcon;
    if (master.muted) {
      volumeIcon = Icons.volume_off_rounded;
    } else if (value == 0) {
      volumeIcon = Icons.volume_mute_rounded;
    } else if (value < 50) {
      volumeIcon = Icons.volume_down_rounded;
    } else {
      volumeIcon = Icons.volume_up_rounded;
    }

    return Row(
      children: [
        // Clickable Mute Icon
        IconButton.filledTonal(
          onPressed: isReady && !isBusy
              ? () => bloc.add(const ToggleVolumeMuteEvent())
              : null,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(volumeIcon, key: ValueKey(volumeIcon), size: 24),
          ),
          style: IconButton.styleFrom(
            backgroundColor: master.muted
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
            foregroundColor: master.muted
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),

        // Slider
        Expanded(
          child: ScrollableVolumeSlider(
            value: value,
            min: min,
            max: max,
            divisions: master.hasRange
                ? (master.maxVolume - master.minVolume)
                : null,
            label: '${master.volume}%',
            isEnabled: isReady,
            onChanged: (next) {
              bloc.add(VolumeSliderChangedEvent(next.round()));
            },
          ),
        ),

        const SizedBox(width: 16),

        // Loading / Percentage text
        SizedBox(
          width: 50,
          child: isBusy
              ? const Center(child: RdeLoadingIndicator(size: 18))
              : Text(
                  '${master.volume}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: master.muted
                        ? colorScheme.error
                        : colorScheme.primary,
                  ),
                ),
        ),
      ],
    );
  }
}

/// A sleek, animated Material 3 Dropdown Menu for devices.
class _OutputPicker extends StatelessWidget {
  const _OutputPicker({required this.outputs});

  final List<AudioOutput> outputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<AudioDevicesBloc>();

    final activeOutput =
        outputs.where((o) => o.isDefault).firstOrNull ??
        (outputs.isNotEmpty ? outputs.first : null);

    if (activeOutput == null) return const SizedBox.shrink();

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(3),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      builder: (context, controller, child) {
        return FilledButton.tonalIcon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: Icon(
            activeOutput.muted ? Icons.volume_off : Icons.speaker,
            size: 18,
          ),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              activeOutput.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Select Output Device',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final output in outputs)
          MenuItemButton(
            onPressed: output.isDefault
                ? null
                : () => bloc.add(SelectAudioOutputEvent(output.name)),
            leadingIcon: Icon(
              output.isDefault ? Icons.check_circle : Icons.speaker,
              size: 20,
              color: output.isDefault
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            child: Text(
              output.label,
              style: TextStyle(
                fontWeight: output.isDefault
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: output.isDefault
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
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
