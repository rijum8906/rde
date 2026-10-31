import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Title, artist line, and loading indicator.
/// The transport controls have been moved to the bottom row.
class NowPlayingTrack extends StatelessWidget {
  const NowPlayingTrack({super.key, required this.media, required this.isBusy});

  final NowPlayingMedia media;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          media.hasTrack ? media.title! : 'No track loaded',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16, // Slightly larger to match the image
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle(media),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  String _subtitle(NowPlayingMedia media) {
    final album = media.album;
    return [
      media.artistLabel,
      if (album != null && album.isNotEmpty) album,
    ].join(' • ');
  }
}
