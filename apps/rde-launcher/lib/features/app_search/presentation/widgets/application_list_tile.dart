import 'package:flutter/material.dart';
import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/application_icon.dart';

/// One search result row.
///
/// Layout: [icon] [name + description] [category chip] [Enter affordance].
/// The selected row gets a left primary rail and a tinted background; the
/// trailing "↵" only appears on the selected row so the keyboard contract
/// is visible without a footer of keycaps.
class ApplicationListTile extends StatelessWidget {
  const ApplicationListTile({
    required this.application,
    required this.selected,
    required this.launching,
    required this.onHover,
    required this.onTap,
    super.key,
  });

  final DesktopApplication application;
  final bool selected;
  final bool launching;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Selection rail: 3-px primary bar on the left edge of the row.
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 11),
              ApplicationIcon(application: application, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            application.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        if (!selected &&
                            application.categoryLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _CategoryTag(label: application.categoryLabel),
                        ],
                      ],
                    ),
                    if (application.description.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        application.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    Icons.keyboard_return_rounded,
                    size: 16,
                    color: colors.primary.withValues(alpha: 0.75),
                  ),
                ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
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
