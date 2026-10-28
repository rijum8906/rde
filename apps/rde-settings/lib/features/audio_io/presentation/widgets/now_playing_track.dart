import 'package:flutter/material.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/curvy_progress.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_transport.dart';

/// Title, artist line, curvy progress bar, and transport controls.
///
/// The controls are a separate widget so the track can swap them for a
/// spinner while a transport action is in flight without rebuilding the
/// title and progress bar.
class NowPlayingTrack extends StatelessWidget {
  const NowPlayingTrack({
    super.key,
    required this.media,
    required this.isBusy,
    required this.onTogglePlayPause,
    required this.onSkipNext,
    required this.onSkipPrevious,
  });

  final NowPlayingMedia media;
  final bool isBusy;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = media.length != null && media.position != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                media.hasTrack ? media.title! : 'No track loaded',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle(media),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              if (progress) ...[
                const SizedBox(height: 10),
                CurvyProgress(
                  position: media.position!,
                  length: media.length!,
                  isPlaying: media.isPlaying,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: RdeLoadingIndicator(size: 20, color: Colors.white),
          )
        else
          NowPlayingTransport(
            media: media,
            onTogglePlayPause: onTogglePlayPause,
            onSkipNext: onSkipNext,
            onSkipPrevious: onSkipPrevious,
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
