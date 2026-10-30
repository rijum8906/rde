// features/audio_io/domain/service/player_resolver.dart

import 'package:flutter/rendering.dart';
import 'package:rde_settings/features/audio_io/domain/entities/now_playing_media.dart';

/// Deduplicates the MPRIS players the bloc reads from the bus.
///
/// Two MPRIS names can report the *same underlying playback*: a browser's own
/// endpoint (`org.mpris.MediaPlayer2.chromium.instance_N`) and the desktop's
/// browser bridge (`org.mpris.MediaPlayer2.chromium.instance_M`) both read
/// the same `<audio>` element, so they agree on the position and the length
/// down to the millisecond. But they report *different things about it*: one
/// has the transport capabilities (`CanGoNext`, `CanGoPrevious`), the other
/// has the metadata (`mpris:artUrl`, `xesam:album`). Merging them gives a
/// card that has both.
///
/// ## What counts as a duplicate
///
/// Two entries describe the same session when:
///
/// 1. **Same player name** — exact, or one is a case-insensitive substring of
///    the other, or both share the same first word. This covers "YouTube
///    Music" vs "YouTubeMusic", "Chromium" vs "Chromium Browser", and
///    "YouTube" vs "YouTube Music".
/// 2. **Same length** — exact, or within [lengthTolerance]. MPRIS reports
///    length in microseconds; different players round differently, so
///    3:00.000 and 2:59.998 are the same track.
/// 3. **Same position** — within [positionTolerance]. The two endpoints can
///    drift by a second or two on pause/play cycles; 5 s is enough to catch
///    that without merging two genuinely different sessions.
///
/// If either entry lacks a `length` or `position`, the time comparison is
/// impossible, so the resolver falls back to **same player name and identical
/// title**. That covers an endpoint that reports a title but no time.
///
/// Entries with neither a time nor a title never merge — two "stopped, no
/// metadata" players are two distinct things.
///
/// ## What the merged entry looks like
///
/// - **Capabilities are the OR of the group.** If either instance can skip
///   next, the merged card shows a Next button.
/// - **Metadata is the entry with the most fields populated**, so the
///   survivor is the entry whose card would look complete (title, artist,
///   album, art). Ties are broken by the playing entry, then the first in
///   the group.
/// - **Fields the survivor lacks are filled from the group**, in order.
/// - **The survivor's [NowPlayingMedia.busName] is the address transport
///   calls go to.** This is the known limitation: if the survivor can't
///   skip but a merged-away entry can, the button is enabled (correctly,
///   because *some* entry can), but the call lands on the survivor and may
///   no-op. Adding `candidateBusNames` would fix that; it's not worth it for
///   a settings-page now-playing widget.
///
/// ## What it does *not* do
///
/// It does not order the result. Ordering is the bloc's job (`_ordered` in
/// `NowPlayingBloc`), because the order is a per-visit policy that depends on
/// what the user has already seen, not on what is on the bus.
class PlayerResolver {
  const PlayerResolver({
    this.positionTolerance = const Duration(seconds: 5),
    this.lengthTolerance = const Duration(seconds: 1),
  });

  /// How far apart two positions can be and still count as "the same
  /// playback." Endpoints reading the same `<audio>` element drift by up to
  /// a few seconds on pause/play cycles.
  final Duration positionTolerance;

  /// How far apart two lengths can be and still count as "the same track."
  /// MPRIS reports microseconds; different players round differently.
  final Duration lengthTolerance;

  /// Groups the players by playback session and merges each group.
  ///
  /// Returns a new list. Entries that could not be matched are kept as-is,
  /// after the merged ones, in their original order.
  List<NowPlayingMedia> resolve(List<NowPlayingMedia> players) {
    if (players.isEmpty) return const [];

    debugPrint(players.toString());

    // Step 1: separate entries that have a time (length + position) from
    // those that don't. Time-keyed entries are candidates for the primary
    // merge rule; unkeyed entries are kept as-is and only merge via the
    // title fallback.
    final timeKeyed = <NowPlayingMedia>[];
    final unkeyed = <NowPlayingMedia>[];
    for (final player in players) {
      if (player.length != null && player.position != null) {
        timeKeyed.add(player);
      } else {
        unkeyed.add(player);
      }
    }

    // Step 2: greedily group the time-keyed entries. For each entry, find
    // the first existing group whose representative matches it; if none,
    // start a new group. Greedy is correct here because "matches" is an
    // equivalence relation in practice (two entries that both match a third
    // are the same session).
    final timeGroups = <List<NowPlayingMedia>>[];
    for (final player in timeKeyed) {
      List<NowPlayingMedia>? target;
      for (final group in timeGroups) {
        if (_sameSession(group.first, player)) {
          target = group;
          break;
        }
      }
      if (target == null) {
        timeGroups.add([player]);
      } else {
        target.add(player);
      }
    }

    // Step 3: fold the unkeyed entries into the time groups by title when
    // possible. An endpoint that reports a title but no length/position can
    // still be the same session as a time-keyed entry — for example, a
    // browser's own endpoint that only reports the track name.
    final leftover = <NowPlayingMedia>[];
    for (final player in unkeyed) {
      var matched = false;
      for (final group in timeGroups) {
        if (_sameTitleFallback(group.first, player)) {
          group.add(player);
          matched = true;
          break;
        }
      }
      if (!matched) {
        // Try to pair the unkeyed entry with another unkeyed entry by title.
        for (var i = 0; i < leftover.length; i++) {
          if (_sameTitleFallback(leftover[i], player)) {
            // Add the second entry to the same group as the first.
            // (The first one is already in `leftover`; replace it with a
            // 2-element group.)
            timeGroups.add([leftover.removeAt(i), player]);
            matched = true;
            break;
          }
        }
        if (!matched) {
          leftover.add(player);
        }
      }
    }

    // Step 4: merge each time group, then append the leftover entries.
    return [for (final group in timeGroups) _merge(group), ...leftover];
  }

  /// Whether two entries describe the same playback session by time.
  bool _sameSession(NowPlayingMedia a, NowPlayingMedia b) {
    // Player name must match first; it's cheap and rules out the obvious
    // false positives.
    if (!_samePlayer(a.playerName, b.playerName)) return false;

    final lenA = a.length;
    final lenB = b.length;
    if (lenA == null || lenB == null) return false;
    if ((lenA - lenB).abs() > lengthTolerance) return false;

    final posA = a.position;
    final posB = b.position;
    if (posA == null || posB == null) return false;
    return (posA - posB).abs() <= positionTolerance;
  }

  /// Whether two entries with no reliable time data can be matched by title.
  bool _sameTitleFallback(NowPlayingMedia a, NowPlayingMedia b) {
    if (!_samePlayer(a.playerName, b.playerName)) return false;
    final titleA = a.title;
    final titleB = b.title;
    if (titleA == null || titleA.isEmpty) return false;
    if (titleB == null || titleB.isEmpty) return false;
    return titleA == titleB;
  }

  /// Whether two player names refer to the same app.
  ///
  /// Exact match, substring either way, or the same first word. The first
  /// word covers "Chromium" vs "Chrome" and "YouTube Music" vs "YouTube",
  /// which the substring check would miss.
  bool _samePlayer(String a, String b) {
    final la = a.toLowerCase().trim();
    final lb = b.toLowerCase().trim();
    if (la == lb) return true;
    if (la.contains(lb) || lb.contains(la)) return true;
    final wa = _firstWord(la);
    final wb = _firstWord(lb);
    return wa.isNotEmpty && wa == wb;
  }

  String _firstWord(String input) {
    for (final part in input.split(RegExp(r'[^a-z0-9]+'))) {
      if (part.isNotEmpty) return part;
    }
    return '';
  }

  /// Collapses one group into a single entry.
  NowPlayingMedia _merge(List<NowPlayingMedia> group) {
    if (group.length == 1) return group.first;

    // Step 1: pick the survivor. The entry with the most metadata fields
    // populated wins, because that's the one whose card looks complete.
    // Ties go to the playing entry, then to the first in the group.
    var survivor = group.first;
    var bestScore = _metadataScore(survivor);
    for (final player in group.skip(1)) {
      final score = _metadataScore(player);
      if (score > bestScore) {
        survivor = player;
        bestScore = score;
      } else if (score == bestScore &&
          player.status == MprisPlaybackStatus.playing &&
          survivor.status != MprisPlaybackStatus.playing) {
        survivor = player;
      }
    }

    // Step 2: OR the capabilities.
    bool any(bool Function(NowPlayingMedia) test) => group.any(test);

    // Step 3: fill in metadata the survivor lacks from the rest of the
    // group. The survivor's own value wins when non-empty.
    String? firstNonNullString(String? Function(NowPlayingMedia) select) {
      final own = select(survivor);
      if (own != null && own.isNotEmpty) return own;
      for (final player in group) {
        final value = select(player);
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    List<String> firstNonEmptyList(
      List<String> Function(NowPlayingMedia) select,
    ) {
      final own = select(survivor);
      if (own.isNotEmpty) return own;
      for (final player in group) {
        final value = select(player);
        if (value.isNotEmpty) return value;
      }
      return const [];
    }

    Duration? firstNonNullDuration(Duration? Function(NowPlayingMedia) select) {
      final own = select(survivor);
      if (own != null) return own;
      for (final player in group) {
        final value = select(player);
        if (value != null) return value;
      }
      return null;
    }

    return NowPlayingMedia(
      busName: survivor.busName,
      playerName: survivor.playerName,
      status: survivor.status,
      title: firstNonNullString((p) => p.title),
      artists: firstNonEmptyList((p) => p.artists),
      album: firstNonNullString((p) => p.album),
      artUrl: firstNonNullString((p) => p.artUrl),
      length: firstNonNullDuration((p) => p.length),
      position: firstNonNullDuration((p) => p.position),
      canControl: any((p) => p.canControl),
      canPlay: any((p) => p.canPlay),
      canPause: any((p) => p.canPause),
      canGoNext: any((p) => p.canGoNext),
      canGoPrevious: any((p) => p.canGoPrevious),
    );
  }

  /// 0–4 score of how many metadata fields the entry fills in.
  ///
  /// The survivor is the entry with the highest score, because that's the
  /// one whose card looks like a full now-playing card instead of a
  /// title-only strip.
  int _metadataScore(NowPlayingMedia media) {
    var score = 0;
    if (media.title != null && media.title!.isNotEmpty) score++;
    if (media.artists.isNotEmpty) score++;
    if (media.album != null && media.album!.isNotEmpty) score++;
    if (media.artUrl != null && media.artUrl!.isNotEmpty) score++;
    return score;
  }
}
