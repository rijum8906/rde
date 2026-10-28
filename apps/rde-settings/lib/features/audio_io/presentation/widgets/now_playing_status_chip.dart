import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Playback state of the selected player, as a small pill.
///
/// The dot color is fixed by state (green = playing, amber = paused, white =
/// stopped), not by the theme, because the pill sits on an arbitrary artwork
/// and a theme-tinted dot would disappear against some covers.
class NowPlayingStatusChip extends StatelessWidget {
  const NowPlayingStatusChip({super.key, required this.media});

  final NowPlayingMedia media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch (media.status) {
      MprisPlaybackStatus.playing => Colors.greenAccent.shade200,
      MprisPlaybackStatus.paused => Colors.amberAccent.shade100,
      MprisPlaybackStatus.stopped => Colors.white70,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            media.statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
