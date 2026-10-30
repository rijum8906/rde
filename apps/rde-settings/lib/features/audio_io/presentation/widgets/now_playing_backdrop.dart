import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Backdrop for the now-playing card.
///
/// Layout: the artwork is a **square the height of the card**, centered
/// horizontally. The space to its left and right is filled with a blurred,
/// scaled-up copy of the same artwork, so the card's sides are the artwork's
/// own colors. The controls are not part of the backdrop — they sit on the
/// artwork in [NowPlayingCard], anchored to its bottom edge.
class NowPlayingBackdrop extends StatelessWidget {
  const NowPlayingBackdrop({super.key, required this.media});

  final NowPlayingMedia media;

  @override
  Widget build(BuildContext context) {
    final uri = _artUri(media.artUrl);
    if (uri == null) return const NoArtworkBackdrop();

    Widget fallback(BuildContext _, Object _, StackTrace? _) =>
        const NoArtworkBackdrop();
    Widget buildImage() {
      return switch (uri.scheme) {
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
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: blurred, scaled artwork filling the whole card — the
        // "gradient" that runs to the left and right of the centered cover.
        Transform.scale(
          scale: 1.4,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: buildImage(),
          ),
        ),
        // Layer 2: a subtle dark tint so the blurred sides read as
        // background, not as the subject.
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
          ),
        ),
        // Layer 3: the sharp, centered artwork. Square, the full height of
        // the card, so the controls can sit on its bottom edge. `BoxFit.cover`
        // keeps the source art from being letterboxed inside the square.
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: buildImage(),
            ),
          ),
        ),
      ],
    );
  }

  Uri? _artUri(String? url) {
    if (url == null || url.isEmpty) return null;
    return Uri.tryParse(url);
  }
}

/// Backdrop used when the player has no artwork.
///
/// Pure theme gradient; there is no artwork tile to sit the controls on, so
/// the card's layout handles the "no artwork" case by placing the controls
/// on the gradient instead.
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
