import 'package:flutter/material.dart';

/// # Launcher Footer
///
/// Shows the match summary and the keyboard affordances available on the
/// launcher surface.
class LauncherFooter extends StatelessWidget {
  /// Creates the launcher footer.
  ///
  /// # Parameters
  /// - [resultCount]: number of matches currently listed.
  /// - [hasQuery]: whether a search query or category filter is active, which
  ///   makes Escape clear the filters instead of closing the launcher.
  const LauncherFooter({
    required this.resultCount,
    required this.hasQuery,
    super.key,
  });

  /// Number of matches currently listed.
  final int resultCount;

  /// Whether a search query or category filter is active.
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.apps_rounded, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            resultCount == 1 ? '1 application' : '$resultCount applications',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const _KeyCap(label: '↑↓'),
        const SizedBox(width: 5),
        Text('navigate', style: theme.textTheme.labelSmall),
        const SizedBox(width: 10),
        const _KeyCap(label: '↵'),
        const SizedBox(width: 5),
        Text('launch', style: theme.textTheme.labelSmall),
        const SizedBox(width: 10),
        const _KeyCap(label: 'esc'),
        const SizedBox(width: 5),
        Text(hasQuery ? 'clear' : 'close', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Small keycap that documents a launcher shortcut.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
