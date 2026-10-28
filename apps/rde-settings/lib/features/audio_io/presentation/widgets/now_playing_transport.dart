import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Previous / play-pause / next buttons.
///
/// Every button is white on the blurred backdrop, with `disabledColor` set to
/// a dimmed white so an unsupported action reads as unavailable instead of
/// just grayed out against the dark scrim.
class NowPlayingTransport extends StatelessWidget {
  const NowPlayingTransport({
    super.key,
    required this.media,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final NowPlayingMedia media;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous track',
          visualDensity: VisualDensity.compact,
          color: Colors.white,
          disabledColor: Colors.white.withValues(alpha: 0.35),
          onPressed: media.canSkipPrevious ? onSkipPrevious : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 2),
        IconButton.filled(
          tooltip: media.isPlaying ? 'Pause' : 'Play',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.35),
          ),
          onPressed: media.canTogglePlayback ? onTogglePlayPause : null,
          icon: Icon(
            media.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Next track',
          visualDensity: VisualDensity.compact,
          color: Colors.white,
          disabledColor: Colors.white.withValues(alpha: 0.35),
          onPressed: media.canSkipNext ? onSkipNext : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
