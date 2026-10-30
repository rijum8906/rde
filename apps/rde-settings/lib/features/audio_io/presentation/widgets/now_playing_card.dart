import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_backdrop.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_nothing.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_status_chip.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_track.dart';

/// Card showing what one MPRIS player is doing.
///
/// Layout:
/// - Backdrop: centered artwork square, blurred copy of itself filling the
///   sides.
/// - Header: "Now Playing" + status pill at the top, over the blurred sides.
/// - Player strip: full-width, anchored to the bottom of the card. It sits
///   on top of the artwork and the blurred sides alike, with its own
///   bottom-heavy scrim so it reads as "the controls at the bottom of the
///   card" rather than "text floating on the cover."
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({
    super.key,
    required this.media,
    required this.isBusy,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final NowPlayingMedia? media;
  final bool isBusy;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;

  static const double height = 200;

  @override
  Widget build(BuildContext context) {
    final media = this.media;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media != null && media.hasArtwork)
              NowPlayingBackdrop(media: media)
            else
              const NoArtworkBackdrop(),
            // Header floats at the top, over the blurred sides.
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _Header(media: media),
            ),
            // Player strip: full width, anchored to the bottom. Its own
            // scrim handles legibility over both the artwork and the sides.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PlayerStrip(
                media: media,
                isBusy: isBusy,
                onTogglePlayPause: onTogglePlayPause,
                onSkipNext: onSkipNext,
                onSkipPrevious: onSkipPrevious,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Now Playing" label + status pill, floating at the top of the card.
class _Header extends StatelessWidget {
  const _Header({required this.media});

  final NowPlayingMedia? media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = this.media;
    return Row(
      children: [
        Icon(
          Icons.graphic_eq_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Now Playing',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (media != null) NowPlayingStatusChip(media: media),
      ],
    );
  }
}

/// Player controls that span the full width of the card's bottom edge.
///
/// The strip paints its own scrim (transparent at the top, dark at the
/// bottom) so the white content is readable over the artwork in the middle
/// and over the blurred gradient on the sides. The scrim is *the* thing that
/// makes the full-width layout work: without it, the white text would
/// disappear over the artwork on a bright cover.
class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({
    required this.media,
    required this.isBusy,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final NowPlayingMedia? media;
  final bool isBusy;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The scrim covers the whole strip: transparent at the top edge (where
      // the artwork is still visible) to a dark wash at the bottom (where
      // the controls are). `stops: [0.0, 0.5]` means the top half of the
      // strip fades from clear to dark, and the bottom half is solid dark.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.70),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: media == null
          ? const NowPlayingNothing()
          : NowPlayingTrack(
              media: media!,
              isBusy: isBusy,
              onTogglePlayPause: onTogglePlayPause,
              onSkipNext: onSkipNext,
              onSkipPrevious: onSkipPrevious,
            ),
    );
  }
}
