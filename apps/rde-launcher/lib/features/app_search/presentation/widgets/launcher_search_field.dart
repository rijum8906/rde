import 'package:core/theme.dart';
import 'package:flutter/material.dart';

/// The launcher's primary input.
///
/// A large, rounded search field with a focus halo. The field is the anchor
/// of the launcher: everything else (header, results, footer) is arranged
/// around it, so its visual weight matches its role.
class LauncherSearchField extends StatefulWidget {
  const LauncherSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<LauncherSearchField> createState() => _LauncherSearchFieldState();
}

class _LauncherSearchFieldState extends State<LauncherSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted || widget.focusNode.hasFocus == _focused) return;
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
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focused
              ? colors.primary.withValues(alpha: 0.7)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.20),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: colors.primary,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w400,
          letterSpacing: -0.3,
        ),
        decoration: InputDecoration(
          hintText: 'Search applications…',
          hintStyle: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: _focused ? colors.primary : colors.onSurfaceVariant,
              size: 24,
            ),
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
