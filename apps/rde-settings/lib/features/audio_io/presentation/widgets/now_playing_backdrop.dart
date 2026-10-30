import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Backdrop for the now-playing card.
///
/// Now uses a full-bleed layout to match the reference design. The artwork
/// fills the entire card, with a subtle dark overlay to ensure white text
/// remains readable.
class NowPlayingBackdrop extends StatelessWidget {
  const NowPlayingBackdrop({super.key, required this.media});

  final NowPlayingMedia media;

  @override
  Widget build(BuildContext context) {
    final uri = _artUri(media.artUrl);
    if (uri == null) return const NoArtworkBackdrop();

    Widget fallback(BuildContext _, Object _, StackTrace? _) =>
        const NoArtworkBackdrop();

    // Image is now a normal widget, not a closure
    final image = switch (uri.scheme) {
      'file' => Image.file(
        File(uri.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: fallback,
      ),
      'http' || 'https' => Image.network(
        uri.toString(),
        fit: BoxFit.cover,
        errorBuilder: fallback,
      ),
      _ => const NoArtworkBackdrop(),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full bleed image
        image,
        // Darkening overlay so white text remains legible over bright covers
        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
      ],
    );
  }

  Uri? _artUri(String? url) {
    if (url == null || url.isEmpty) return null;
    return Uri.tryParse(url);
  }
}

/// Backdrop used when the player has no artwork.
class NoArtworkBackdrop extends StatelessWidget {
  const NoArtworkBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
          ],
        ),
      ),
    );
  }
}
