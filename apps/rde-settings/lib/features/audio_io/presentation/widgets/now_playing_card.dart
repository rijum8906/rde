import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_backdrop.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_nothing.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_status_chip.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_track.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_transport.dart';

class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({
    super.key,
    required this.media,
    required this.isBusy,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
    this.outputDeviceName,
  });

  final NowPlayingMedia? media;
  final bool isBusy;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final String? outputDeviceName;

  static const double height = 240;

  @override
  Widget build(BuildContext context) {
    final media = this.media;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background
            if (media != null && media.hasArtwork)
              NowPlayingBackdrop(media: media)
            else
              const NoArtworkBackdrop(),

            // 2. Vignette
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.5, 1.0],
                  radius: 1.0,
                ),
              ),
            ),

            // 3. Content Layout
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              child: Column(
                children: [
                  // ── ROW 1: Top (App Icon Left, Speaker Right) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      if (media != null)
                        NowPlayingStatusChip(
                          media: media,
                          deviceName: outputDeviceName,
                        ),
                    ],
                  ),

                  // ── ROW 2: Middle (Title/Art Left, Play/Pause Right) ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: media == null
                              ? const NowPlayingNothing()
                              : NowPlayingTrack(media: media, isBusy: isBusy),
                        ),
                        const SizedBox(width: 16),

                        // CRASH FIX: Wrapped in a Builder to capture media! safely
                        if (media != null)
                          Builder(
                            builder: (context) {
                              final activeMedia = media!;
                              return SizedBox(
                                width: 53,
                                height: 53,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFBE0C3),
                                    splashFactory: NoSplash.splashFactory,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.zero,
                                    shape: activeMedia.isPlaying
                                        ? RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          )
                                        : const CircleBorder(),
                                  ),
                                  onPressed: activeMedia.canTogglePlayback
                                      ? onTogglePlayPause
                                      : null,
                                  child: Icon(
                                    activeMedia.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 32,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // ── ROW 3: Bottom (Controls + Waveform) ──
                  const SizedBox(height: 16),
                  if (media != null)
                    NowPlayingTransport(
                      media: media,
                      isPlaying: media.isPlaying, // Pass the playing state
                      onTogglePlayPause: onTogglePlayPause,
                      onSkipNext: onSkipNext,
                      onSkipPrevious: onSkipPrevious,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
