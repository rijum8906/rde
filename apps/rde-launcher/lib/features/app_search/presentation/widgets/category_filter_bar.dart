import 'package:core/theme.dart';
import 'package:flutter/material.dart';

/// # Category Filter Bar
///
/// Horizontal set of animated category chips that narrows the application list
/// without typing, keeping the launcher useful for browsing.
class CategoryFilterBar extends StatelessWidget {
  /// Creates the category filter bar.
  ///
  /// # Parameters
  /// - [categories]: display labels available in the loaded catalog.
  /// - [selected]: active label, or an empty string for every category.
  /// - [onSelected]: called with the tapped label.
  const CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Display labels available in the loaded catalog.
  final List<String> categories;

  /// Active label, or an empty string for every category.
  final String selected;

  /// Called with the tapped label.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final label = index == 0 ? '' : categories[index - 1];
          return _CategoryChip(
            label: index == 0 ? 'All' : label,
            selected: selected == label,
            onTap: () => onSelected(label),
          );
        },
      ),
    );
  }
}

/// Pill-shaped filter chip with an animated selection fill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final motion = RdeThemeMotion.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.short,
          curve: motion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: AnimatedDefaultTextStyle(
            duration: motion.short,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
