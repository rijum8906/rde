import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/core/widgets/rde_slider.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_state.dart';

import 'audio_device_picker.dart'; // <-- Import the new picker

class MicrophoneCard extends StatelessWidget {
  const MicrophoneCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final state = context.watch<AudioDevicesBloc>().state;
    final devices = state.devices;
    final hasInput = devices?.hasInput ?? false;
    final isReady = state.status == AudioDevicesStatus.success && hasInput;
    final inputs = devices?.inputs ?? const <AudioInput>[];

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
                      'Microphone',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Adjust capture volume and input device',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Use the new picker
              if (inputs.isNotEmpty) AudioInputPicker(inputs: inputs),
            ],
          ),
          const SizedBox(height: 32),

          // Content
          if (!hasInput)
            Text(
              state.status == AudioDevicesStatus.loading
                  ? 'Looking for a microphone…'
                  : 'No microphone was found on the audio server.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            _MicControls(devices: devices!, state: state, isReady: isReady),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ... (_MicControls stays exactly the same as before)

class _MicControls extends StatelessWidget {
  const _MicControls({
    required this.devices,
    required this.state,
    required this.isReady,
  });

  final AudioDevices devices;
  final AudioDevicesState state;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AudioDevicesBloc>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isMuted = devices.inputMuted;
    final volume = devices.inputVolume;

    return Row(
      children: [
        // Clickable Mute Icon
        IconButton.filledTonal(
          onPressed: isReady && !state.isBusy
              ? () => bloc.add(const ToggleMicrophoneMuteEvent())
              : null,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              key: ValueKey(isMuted),
              size: 24,
            ),
          ),
          style: IconButton.styleFrom(
            backgroundColor: isMuted
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
            foregroundColor: isMuted
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),

        // Slider
        Expanded(
          child: RdeSlider(
            value: volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$volume%',
            isEnabled: isReady,
            onChanged: (value) =>
                bloc.add(MicrophoneVolumeSetEvent(value.round())),
          ),
        ),

        const SizedBox(width: 16),

        // Loading / Percentage text
        SizedBox(
          width: 50,
          child: state.isBusy
              ? const Center(child: RdeLoadingIndicator(size: 18))
              : Text(
                  '$volume%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMuted ? colorScheme.error : colorScheme.primary,
                  ),
                ),
        ),
      ],
    );
  }
}
