import 'package:flutter/material.dart';

class RdeIconButton extends StatelessWidget {
  const RdeIconButton({
    super.key,
    required this.icon,
    required this.value,
    required this.onPressed,
    this.width = 60.0, // Made it wider like a rectangle
    this.height = 48.0, // Standard height
  });

  final IconData icon;
  final bool value;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(value ? 16.0 : height / 2),

          // Color logic: Tinted blue when ON, grey/neutral when OFF
          color: value
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              icon,
              key: ValueKey(value),
              size: 24, // Standard icon size
              color: value
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
