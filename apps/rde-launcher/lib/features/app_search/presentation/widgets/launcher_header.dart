import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// # Launcher Header
///
/// Branding row for the launcher: product mark, installed application count,
/// and the catalog refresh action.
class LauncherHeader extends StatelessWidget {
  /// Creates the launcher header.
  ///
  /// # Parameters
  /// - [applicationCount]: number of discovered applications.
  /// - [isLoading]: whether discovery is running.
  /// - [onRefresh]: reloads the application catalog.
  const LauncherHeader({
    required this.applicationCount,
    required this.isLoading,
    required this.onRefresh,
    super.key,
  });

  /// Number of discovered applications.
  final int applicationCount;

  /// Whether discovery is running.
  final bool isLoading;

  /// Reloads the application catalog.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = RdeThemeMotion.of(context);

    return Row(
      children: [
        // Step 1: Gradient product mark.
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primary, colors.tertiary],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.rocket_launch_rounded, color: colors.onPrimary),
        ),
        const SizedBox(width: 14),

        // Step 2: Title with an animated installed-count badge.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'RDE Launcher',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 9),
                  AnimatedSwitcher(
                    duration: motion.short,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: _CountBadge(
                      key: ValueKey(applicationCount),
                      count: applicationCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Everything installed, one keystroke away',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Step 3: Refresh the catalog without closing the launcher.
        Tooltip(
          message: 'Rescan installed applications',
          child: InkWell(
            onTap: isLoading ? null : onRefresh,
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: motion.short,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: AnimatedSwitcher(
                duration: motion.short,
                child: isLoading
                    ? const Padding(
                        key: ValueKey('refresh-loading'),
                        padding: EdgeInsets.all(11),
                        child: RdeLoadingIndicator(
                          size: 18,
                          semanticsLabel: 'Refreshing applications',
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        key: const ValueKey('refresh-idle'),
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small rounded count badge shown beside the launcher title.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
