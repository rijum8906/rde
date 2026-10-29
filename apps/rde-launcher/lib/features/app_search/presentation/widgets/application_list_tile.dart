import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:rde_launcher/features/app_search/domain/entities/desktop_application.dart';

/// # Application List Tile
///
/// One search result: icon, name, description, category, and the selected and
/// launching affordances that make keyboard navigation legible.
class ApplicationListTile extends StatefulWidget {
  /// Creates an application result tile.
  ///
  /// # Parameters
  /// - [application]: result to render.
  /// - [selected]: whether keyboard focus highlights this result.
  /// - [launching]: whether this result is currently starting.
  /// - [onHover]: called when the pointer enters the tile.
  /// - [onTap]: launches the application.
  const ApplicationListTile({
    required this.application,
    required this.selected,
    required this.launching,
    required this.onHover,
    required this.onTap,
    super.key,
  });

  /// Result to render.
  final DesktopApplication application;

  /// Whether keyboard focus highlights this result.
  final bool selected;

  /// Whether this result is currently starting.
  final bool launching;

  /// Called when the pointer enters the tile.
  final VoidCallback onHover;

  /// Launches the application.
  final VoidCallback onTap;

  @override
  State<ApplicationListTile> createState() => _ApplicationListTileState();
}

class _ApplicationListTileState extends State<ApplicationListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = widget.selected;
    final foreground = colors.onSurface;

    // Step 1: Hover only adds a faint primary wash and a gentle lift, so the
    // row stays quiet; keyboard selection adds the accent rail on top.
    final hoverTint = colors.primary.withValues(alpha: 0.05);
    final selectedTint = colors.primary.withValues(alpha: 0.09);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.005 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? selectedTint
                  : _hovered
                  ? hoverTint
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? colors.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _ApplicationIcon(application: widget.application),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.application.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (widget.application.categoryLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _CategoryTag(
                              label: widget.application.categoryLabel,
                              selected: selected,
                            ),
                          ],
                        ],
                      ),
                      if (widget.application.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.application.description,
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
                // Step 3: Only a launching row shows a trailing affordance.
                if (widget.launching)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: RdeLoadingIndicator(
                      size: 18,
                      semanticsLabel: 'Launching application',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded, shadowed application icon with a themed letter fallback.
class _ApplicationIcon extends StatelessWidget {
  const _ApplicationIcon({required this.application});

  final DesktopApplication application;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconPath = application.iconPath;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(5),
      child: iconPath == null
          ? _fallback(colors)
          : Image.file(
              File(iconPath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _fallback(colors),
            ),
    );
  }

  Widget _fallback(ColorScheme colors) {
    final initial = application.name.isEmpty
        ? '?'
        : application.name.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

/// Compact category label shown beside an application name.
class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected
              ? colors.primary.withValues(alpha: 0.9)
              : colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
