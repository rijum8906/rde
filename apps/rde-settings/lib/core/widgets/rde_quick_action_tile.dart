import 'package:flutter/material.dart';

class RdeQuickActionTile extends StatelessWidget {
  const RdeQuickActionTile({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.size = 64.0,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: size + 15,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isActive ? 20.0 : size / 2),
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              icon,
              key: ValueKey(icon),
              size: 30,
              color: isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
