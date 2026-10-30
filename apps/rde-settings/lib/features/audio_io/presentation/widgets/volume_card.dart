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

import 'audio_device_picker.dart'; // <-- Import the new picker
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
              // Use the new picker
              if (outputs.isNotEmpty) AudioOutputPicker(outputs: outputs),
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

/// A sleek, custom Material 3 Dropdown using OverlayPortal.
class _OutputPicker extends StatefulWidget {
  const _OutputPicker({required this.outputs});

  final List<AudioOutput> outputs;

  @override
  State<_OutputPicker> createState() => _OutputPickerState();
}

class _OutputPickerState extends State<_OutputPicker> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();

  void _toggle() {
    if (_controller.isShowing) {
      _controller.hide();
    } else {
      _controller.show();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<AudioDevicesBloc>();

    final activeOutput =
        widget.outputs.where((o) => o.isDefault).firstOrNull ??
        (widget.outputs.isNotEmpty ? widget.outputs.first : null);

    if (activeOutput == null) return const SizedBox.shrink();

    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8), // Gap below the button
          child: Align(
            alignment: Alignment.topRight,
            child: _DropdownMenu(
              outputs: widget.outputs,
              onSelect: (name) {
                bloc.add(SelectAudioOutputEvent(name));
                _toggle();
              },
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _controller.isShowing
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _controller.isShowing
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: Icon(
                    activeOutput.muted
                        ? Icons.volume_off_rounded
                        : Icons.speaker_rounded,
                    key: ValueKey(activeOutput.muted),
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    activeOutput.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _controller.isShowing ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  const _DropdownMenu({required this.outputs, required this.onSelect});

  final List<AudioOutput> outputs;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          alignment: Alignment.topRight,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'OUTPUT DEVICE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final output in outputs)
                  InkWell(
                    onTap: output.isDefault
                        ? null
                        : () => onSelect(output.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            output.isDefault
                                ? Icons.check_circle_rounded
                                : Icons.speaker_rounded,
                            size: 20,
                            color: output.isDefault
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              output.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
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
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
