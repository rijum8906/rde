import 'package:flutter/material.dart';

/// Centered, muted explanation shown when a card has nothing to list.
///
/// Used by [WifiRadioCard] when no networks are in range and by
/// [WifiSavedCard] when there are no saved profiles. Styling matches the
/// Bluetooth page's "No devices yet" message so the two pages read the same.
class WifiEmptyMessage extends StatelessWidget {
  const WifiEmptyMessage({super.key, required this.text});

  /// The message. Should be one or two short sentences in sentence case,
  /// explaining what the user can do to populate the card.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
