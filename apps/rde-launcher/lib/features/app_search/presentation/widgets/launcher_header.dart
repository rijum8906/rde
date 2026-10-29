import 'package:flutter/material.dart';

/// Launcher header: the RDE wordmark, the installed count, and the refresh
/// action. No branding tile — the launcher's identity is its search field,
/// and the header is a quiet label above it.
class LauncherHeader extends StatelessWidget {
  const LauncherHeader({
    required this.applicationCount,
    required this.isLoading,
    required this.onRefresh,
    super.key,
  });

  final int applicationCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final countLabel = applicationCount == 1
        ? '1 application'
        : '$applicationCount applications';

    return Row(
      children: [
        RichText(
          text: TextSpan(
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            children: [
              const TextSpan(text: 'RDE'),
              TextSpan(
                text: ' Launcher',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          countLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: isLoading ? null : onRefresh,
          icon: AnimatedRotation(
            turns: isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
          label: Text(
            'Refresh',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    );
  }
}
