import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_card.dart';

/// Slider holding one [NowPlayingCard] per player.
///
/// The page opens on the player the bloc prefers - a playing one - and swiping
/// left or right reaches the others, which is what the card offers when several
/// players are open at once. With a single player the slider does not scroll
/// and no dots are shown, so a one-player desktop looks like a plain card.
///
/// The cards are laid out at a fixed height ([cardHeight]) because a
/// `PageView` needs a bounded height; the card keeps every line to one line, so
/// no page can grow taller than another while swiping.
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

  /// Whether the controller is animating or jumping to a page the bloc picked.
  ///
  /// A programmatic move reports every page it passes as a page change, which
  /// would send the intermediate players back to the bloc and interrupt the
  /// animation, so those reports are ignored.
  bool _syncing = false;

  /// The in-flight `animateToPage` future, if any.
  ///
  /// Guarding with a future (rather than a bare bool) means a second
  /// `didUpdateWidget` while the first animation is still running does not
  /// start a competing animation. The next change will start a fresh sync
  /// after this one settles.
  Future<void>? _syncFuture;

  @override
  void didUpdateWidget(NowPlayingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    final indexChanged = oldWidget.activeIndex != widget.activeIndex;
    if (!indexChanged) return;

    // A change in list length means the controller's current page may no
    // longer exist (a player exited), so animating would render the
    // intermediate page with the wrong content. Jump instead.
    final listChanged = oldWidget.players.length != widget.players.length;
    if (listChanged) {
      _jumpToActivePage();
    } else {
      _syncToActivePage();
    }
  }

  @override
  void dispose() {
    _syncFuture = null; // drop the reference; the controller disposes the rest
    _controller.dispose();
    super.dispose();
  }

  /// Jumps to the active page without animating. Used when the list length
  /// changed, because animating would render intermediate pages with content
  /// that no longer matches the controller's index.
  void _jumpToActivePage() {
    if (!_controller.hasClients) return;
    _syncing = true;
    _controller.jumpToPage(widget.activeIndex);
    _syncing = false;
  }

  /// Animates to the active page without feeding the intermediate pages back
  /// as selections.
  ///
  /// Re-entrant-safe: a second call while the first animation is running is
  /// dropped, and the next `didUpdateWidget` after the first settles starts a
  /// fresh sync if `activeIndex` is still out of date.
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

    // Clamp in case the bloc handed us an index that no longer exists (the
    // list shrank between the bloc's selection and this build).
    final safeActive = players.isEmpty
        ? 0
        : widget.activeIndex.clamp(0, players.length - 1);

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
              // The list may have shrunk while the animation was running;
              // silently ignore indices that no longer exist.
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
