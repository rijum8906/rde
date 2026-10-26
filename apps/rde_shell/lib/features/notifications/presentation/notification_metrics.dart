// Geometry shared by the notification lane and the layer-surface controller.

/// Fixed geometry for the top-centre notification lane.
///
/// Card heights are fixed so the lane height, and therefore the layer surface
/// height, can be computed synchronously when the queue changes.
abstract final class NotificationMetrics {
  /// Height of a single notification card.
  static const double cardHeight = 96;

  /// Vertical gap between stacked cards.
  static const double cardGap = 10;

  /// Space above the first card.
  static const double laneTopPadding = 6;

  /// Space below the last card.
  static const double laneBottomPadding = 12;

  /// Maximum width of a card, keeping lines readable on wide monitors.
  static const double maxCardWidth = 520;

  /// Horizontal inset from the screen edges.
  static const double horizontalMargin = 24;

  /// Height of the "more notifications" chip.
  static const double moreChipHeight = 26;

  /// Gap between the last card and the "more notifications" chip.
  static const double moreChipGap = 8;

  /// Maximum number of cards visible at once.
  static const int maxVisible = 3;

  /// Returns the lane height for [visible] cards and the pending overflow.
  static double laneHeight({required int visible, required int pending}) {
    if (visible <= 0) {
      return 0;
    }

    final double cards =
        visible * cardHeight +
        (visible - 1) * cardGap +
        laneTopPadding +
        laneBottomPadding;

    return pending > 0 ? cards + moreChipGap + moreChipHeight : cards;
  }
}
