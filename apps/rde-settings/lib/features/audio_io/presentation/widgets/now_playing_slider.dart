import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/audio_devices_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_card.dart';

/// Slider holding one [NowPlayingCard] per player.
class NowPlayingSlider extends StatefulWidget {
  const NowPlayingSlider({
    super.key,
    required this.players,
    required this.activeIndex,
    required this.isBusy,
    required this.onSelect,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final List<NowPlayingMedia> players;
  final int activeIndex;
  final bool isBusy;
  final ValueChanged<String> onSelect;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;

  static const double cardHeight = 200;

  @override
  State<NowPlayingSlider> createState() => _NowPlayingSliderState();
}

class _NowPlayingSliderState extends State<NowPlayingSlider> {
  late final PageController _controller = PageController(
    initialPage: widget.activeIndex,
  );

  bool _syncing = false;
  Future<void>? _syncFuture;

  @override
  void didUpdateWidget(NowPlayingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    final indexChanged = oldWidget.activeIndex != widget.activeIndex;
    if (!indexChanged) return;

    final listChanged = oldWidget.players.length != widget.players.length;
    if (listChanged) {
      _jumpToActivePage();
    } else {
      _syncToActivePage();
    }
  }

  @override
  void dispose() {
    _syncFuture = null;
    _controller.dispose();
    super.dispose();
  }

  void _jumpToActivePage() {
    if (!_controller.hasClients) return;
    _syncing = true;
    _controller.jumpToPage(widget.activeIndex);
    _syncing = false;
  }

  Future<void> _syncToActivePage() async {
    if (!_controller.hasClients) return;
    if (_syncFuture != null) return;

    _syncing = true;
    _syncFuture = _controller.animateToPage(
      widget.activeIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    try {
      await _syncFuture;
    } finally {
      _syncFuture = null;
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final isSlider = players.length > 1;

    final safeActive = players.isEmpty
        ? 0
        : widget.activeIndex.clamp(0, players.length - 1);

    // Get the current output device label from the AudioDevicesBloc
    final devices = context.watch<AudioDevicesBloc>().state.devices;
    final outputDeviceName = devices?.outputLabel;

    return Column(
      children: [
        SizedBox(
          height: NowPlayingSlider.cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: players.isEmpty ? 1 : players.length,
            physics: isSlider
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              if (_syncing || !isSlider) return;
              if (index < 0 || index >= players.length) return;
              widget.onSelect(players[index].busName);
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: NowPlayingCard(
                media: index < players.length ? players[index] : null,
                isBusy: widget.isBusy,
                onTogglePlayPause: widget.onTogglePlayPause,
                onSkipNext: widget.onSkipNext,
                onSkipPrevious: widget.onSkipPrevious,
                // Pass the output device name down to the card
                outputDeviceName: outputDeviceName,
              ),
            ),
          ),
        ),
        if (isSlider) ...[
          const SizedBox(height: 12),
          _PageDots(
            count: players.length,
            activeIndex: safeActive,
            onSelect: (index) => widget.onSelect(players[index].busName),
          ),
        ],
      ],
    );
  }
}

/// One dot per player, tappable to jump straight to it.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
    required this.onSelect,
  });

  final int count;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          InkWell(
            key: ValueKey('now-playing-dot-$index'),
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: index == activeIndex ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == activeIndex
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
