import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Playback state of the selected player, as a small pill.
class NowPlayingStatusChip extends StatelessWidget {
  const NowPlayingStatusChip({super.key, required this.media, this.deviceName});

  final NowPlayingMedia media;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE0C3), // Peach background
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speaker_rounded, size: 16, color: Colors.black),
          const SizedBox(width: 8),
          // AnimatedSize lets the pill expand/shrink gracefully if the device name changes
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                deviceName ?? "This device",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
