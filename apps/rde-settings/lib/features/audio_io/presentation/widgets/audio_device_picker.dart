import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/audio_io/domain/entities/audio_devices.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_event.dart';

/// A sleek, custom Material 3 Dropdown for selecting an Output Device.
class AudioOutputPicker extends StatelessWidget {
  const AudioOutputPicker({super.key, required this.outputs});

  final List<AudioOutput> outputs;

  @override
  Widget build(BuildContext context) {
    final activeOutput =
        outputs.where((o) => o.isDefault).firstOrNull ??
        (outputs.isNotEmpty ? outputs.first : null);

    if (activeOutput == null) return const SizedBox.shrink();

    return _BasePicker(
      title: 'OUTPUT DEVICE',
      activeLabel: activeOutput.label,
      isMuted: activeOutput.muted,
      iconData: activeOutput.muted
          ? Icons.volume_off_rounded
          : Icons.speaker_rounded,
      items: outputs.map((o) {
        return _PickerItem(
          label: o.label,
          isSelected: o.isDefault,
          isMuted: o.muted,
          onSelect: () => context.read<AudioDevicesBloc>().add(
            SelectAudioOutputEvent(o.name),
          ),
        );
      }).toList(),
    );
  }
}

/// A sleek, custom Material 3 Dropdown for selecting an Input Device.
class AudioInputPicker extends StatelessWidget {
  const AudioInputPicker({super.key, required this.inputs});

  final List<AudioInput> inputs;

  @override
  Widget build(BuildContext context) {
    final activeInput =
        inputs.where((i) => i.isDefault).firstOrNull ??
        (inputs.isNotEmpty ? inputs.first : null);

    if (activeInput == null) return const SizedBox.shrink();

    return _BasePicker(
      title: 'INPUT DEVICE',
      activeLabel: activeInput.label,
      isMuted: activeInput.muted,
      iconData: activeInput.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
      items: inputs.map((i) {
        return _PickerItem(
          label: i.label,
          isSelected: i.isDefault,
          isMuted: i.muted,
          onSelect: () => context.read<AudioDevicesBloc>().add(
            SelectAudioInputEvent(i.name),
          ),
        );
      }).toList(),
    );
  }
}

/// Internal model to unify Output and Input devices.
class _PickerItem {
  final String label;
  final bool isSelected;
  final bool isMuted;
  final VoidCallback onSelect;

  _PickerItem({
    required this.label,
    required this.isSelected,
    required this.isMuted,
    required this.onSelect,
  });
}

/// The shared stateful logic for both Input and Output pickers.
class _BasePicker extends StatefulWidget {
  final String title;
  final String activeLabel;
  final bool isMuted;
  final IconData iconData;
  final List<_PickerItem> items;

  const _BasePicker({
    required this.title,
    required this.activeLabel,
    required this.isMuted,
    required this.iconData,
    required this.items,
  });

  @override
  State<_BasePicker> createState() => _BasePickerState();
}

class _BasePickerState extends State<_BasePicker> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  bool _isVisible = false;

  void _show() {
    setState(() => _isVisible = true);
    _controller.show();
  }

  void _hide() {
    setState(() => _isVisible = false);
    // Delay actual removal from the overlay tree so the exit animation finishes
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isVisible && _controller.isShowing) {
        _controller.hide();
      }
    });
  }

  void _toggle() {
    if (_isVisible) {
      _hide();
    } else {
      _show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        return Stack(
          children: [
            // 1. Full-screen invisible barrier to catch outside clicks
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggle,
                child: const SizedBox.expand(),
              ),
            ),

            // 2. The floating menu
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Align(
                alignment: Alignment.topRight,
                child: _DropdownMenu(
                  title: widget.title,
                  items: widget.items,
                  isVisible: _isVisible,
                  onSelect: (onSelectCallback) {
                    onSelectCallback();
                    _hide();
                  },
                ),
              ),
            ),
          ],
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
              color: _isVisible
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isVisible
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
                    widget.iconData,
                    key: ValueKey(widget.isMuted),
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    widget.activeLabel,
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
                  turns: _isVisible ? 0.5 : 0.0,
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

/// The animated popup menu itself.
class _DropdownMenu extends StatelessWidget {
  final String title;
  final List<_PickerItem> items;
  final bool isVisible;
  final ValueChanged<VoidCallback> onSelect;

  const _DropdownMenu({
    required this.title,
    required this.items,
    required this.isVisible,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedScale(
      scale: isVisible ? 1.0 : 0.95,
      alignment: Alignment.topRight,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
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
                      title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final item in items)
                    InkWell(
                      onTap: item.isSelected
                          ? null
                          : () => onSelect(item.onSelect),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isSelected
                                  ? Icons.check_circle_rounded
                                  : (item.isMuted
                                        ? Icons.volume_off_rounded
                                        : Icons.speaker_rounded),
                              size: 20,
                              color: item.isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: item.isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: item.isSelected
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
      ),
    );
  }
}
