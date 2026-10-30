import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_state.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/scrollable_volume_slider.dart';

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
              if (inputs.isNotEmpty) _InputPicker(inputs: inputs),
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
          child: ScrollableVolumeSlider(
            value: volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$volume%',
            isEnabled: isReady,
            onChanged: (value) =>
                bloc.add(MicrophoneVolumeChangedEvent(value.round())),
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

class _InputPicker extends StatelessWidget {
  const _InputPicker({required this.inputs});

  final List<AudioInput> inputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<AudioDevicesBloc>();

    final activeInput =
        inputs.where((i) => i.isDefault).firstOrNull ??
        (inputs.isNotEmpty ? inputs.first : null);

    if (activeInput == null) return const SizedBox.shrink();

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
          icon: Icon(activeInput.muted ? Icons.mic_off : Icons.mic, size: 18),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              activeInput.label,
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
            'Select Input Device',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final input in inputs)
          MenuItemButton(
            onPressed: input.isDefault
                ? null
                : () => bloc.add(SelectAudioInputEvent(input.name)),
            leadingIcon: Icon(
              input.isDefault ? Icons.check_circle : Icons.mic,
              size: 20,
              color: input.isDefault
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            child: Text(
              input.label,
              style: TextStyle(
                fontWeight: input.isDefault
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: input.isDefault
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
