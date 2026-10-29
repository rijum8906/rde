import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// # Launcher States
///
/// Placeholders shared by the launcher while the catalog loads, matches
/// nothing, or fails to load.

/// Shown while the installed application catalog is being indexed.
class LauncherLoading extends StatelessWidget {
  /// Creates the loading placeholder.
  const LauncherLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RdeLoadingIndicator(size: 46),
          const SizedBox(height: 18),
          Text(
            'Indexing your applications…',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shown when there is nothing to list or discovery failed.
class LauncherMessage extends StatelessWidget {
  /// Creates the message placeholder.
  ///
  /// # Parameters
  /// - [icon]: leading glyph.
  /// - [title]: short headline.
  /// - [message]: supporting line.
  /// - [actionLabel]: optional recovery action label.
  /// - [onAction]: optional recovery action callback.
  const LauncherMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Leading glyph.
  final IconData icon;

  /// Short headline.
  final String title;

  /// Supporting line.
  final String message;

  /// Optional recovery action label.
  final String? actionLabel;

  /// Optional recovery action callback.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Step 1: Reveal the placeholder once when it replaces the list, so an
    // empty search does not snap into place.
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(icon, size: 28, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 300,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
