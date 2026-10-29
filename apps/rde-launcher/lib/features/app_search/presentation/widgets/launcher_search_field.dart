import 'package:core/theme.dart';
import 'package:flutter/material.dart';

/// # Launcher Search Field
///
/// Large, focus-aware search field that makes the entry point of the launcher
/// the visually dominant element.
class LauncherSearchField extends StatefulWidget {
  /// Creates the search field.
  ///
  /// # Parameters
  /// - [controller]: text controller owned by the page.
  /// - [focusNode]: focus node that also receives launcher navigation keys.
  /// - [onChanged]: called with every edited query.
  const LauncherSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    super.key,
  });

  /// Text controller owned by the page.
  final TextEditingController controller;

  /// Focus node that also receives launcher navigation keys.
  final FocusNode focusNode;

  /// Called with every edited query.
  final ValueChanged<String> onChanged;

  @override
  State<LauncherSearchField> createState() => _LauncherSearchFieldState();
}

class _LauncherSearchFieldState extends State<LauncherSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();

    // Step 1: Track focus so the field can grow a colored halo while the user
    // types, without reserving the halo while the window is idle.
    widget.focusNode.addListener(_handleFocusChange);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted || widget.focusNode.hasFocus == _focused) {
      return;
    }
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = RdeThemeMotion.of(context);

    return AnimatedContainer(
      duration: motion.short,
      curve: motion.standard,
      decoration: BoxDecoration(
        color: _focused
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused
              ? colors.primary.withValues(alpha: 0.85)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: _focused ? 1.6 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: colors.primary,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          hintText: 'Search applications…',
          hintStyle: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.72),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: AnimatedSwitcher(
              duration: motion.short,
              child: Icon(
                _focused ? Icons.search_rounded : Icons.search_outlined,
                key: ValueKey(_focused),
                color: _focused ? colors.primary : colors.onSurfaceVariant,
                size: 23,
              ),
            ),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: _EscapeHint(),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}

/// Compact `esc` keycap shown while the search field is empty.
class _EscapeHint extends StatelessWidget {
  const _EscapeHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        'esc',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
