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

    // Inside NowPlayingStatusChip build method:
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE0C3), // Peach background
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smartphone, size: 16, color: Colors.black),
          const SizedBox(width: 8),
          Text(
            "This phone", // Or media.statusLabel
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
