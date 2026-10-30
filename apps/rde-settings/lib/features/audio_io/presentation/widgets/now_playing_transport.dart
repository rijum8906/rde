import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/curvy_progress.dart';

/// The horizontal control bar at the bottom of the card.
///
/// Matches the reference image:
/// [Previous] ─── [Waveform Progress] ─── [Next] ─── [Thumb Up] ─── [Shuffle]
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
      children: [
        // 1. Previous Button
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.white,
          disabledColor: Colors.white.withValues(alpha: 0.35),
          onPressed: media.canSkipPrevious ? onSkipPrevious : null,
          icon: const Icon(Icons.skip_previous_rounded, size: 28),
        ),

        const SizedBox(width: 16),

        // 2. Waveform Progress Bar (replaces the old flat line)
        Expanded(
          child: media.length != null && media.position != null
              ? CurvyProgress(
                  position: media.position!,
                  length: media.length!,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(
                    alpha: 0.25,
                  ), // Faint line for unplayed
                  height: 24,
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(width: 16),

        // 3. Next Button
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.white,
          disabledColor: Colors.white.withValues(alpha: 0.35),
          onPressed: media.canSkipNext ? onSkipNext : null,
          icon: const Icon(Icons.skip_next_rounded, size: 28),
        ),

        const SizedBox(width: 24),

        // 4. Like (Thumb Up) Button
        // Note: You'll need to wire this to your actual logic later
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.white,
          onPressed: () {
            // TODO: implement like
          },
          icon: const Icon(Icons.thumb_up_outlined, size: 24),
        ),

        const SizedBox(width: 16),

        // 5. Shuffle Button
        // Note: You'll need to wire this to your actual logic later
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.white,
          onPressed: () {
            // TODO: implement shuffle
          },
          icon: const Icon(Icons.shuffle_rounded, size: 24),
        ),
      ],
    );
  }
}
