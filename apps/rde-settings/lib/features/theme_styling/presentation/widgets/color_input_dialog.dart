import 'package:flutter/material.dart';
import 'package:core/theme.dart';

/// Dialog that edits the accent color as a hex string.
///
/// Returns the trimmed hex string via `Navigator.pop` when the user confirms,
/// or `null` when dismissed. Validation accepts anything
/// [ThemeColor.parseArgb] understands (`#RGB`, `#RRGGBB`, `#AARRGGBB`, with or
/// without the leading `#`).
class ColorInputDialog extends StatefulWidget {
  const ColorInputDialog({super.key, required this.initialColor});

  /// Hex color the field opens with; falls back to the Material seed when empty.
  final String initialColor;

  @override
  State<ColorInputDialog> createState() => _ColorInputDialogState();
}

class _ColorInputDialogState extends State<ColorInputDialog> {
  static const String _fallbackColor = '#6750A4';

  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialColor.isEmpty ? _fallbackColor : widget.initialColor,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final color = _controller.text.trim();

    if (ThemeColor.parseArgb(color) == null) {
      setState(() => _error = 'Enter a hex color such as #006A6A or #06A.');
      return;
    }

    Navigator.of(context).pop(color);
  }

  void _selectPreset(String hex) {
    setState(() {
      _controller.text = hex;
      // Move the cursor to the end so subsequent typing appends rather than
      // prepends. Without this, picking a preset leaves the cursor at 0 and
      // the next keystroke produces "#7#6750A4"-style garbage.
      _controller.selection = TextSelection.collapsed(offset: hex.length);
      _error = null;
    });
  }

  void _revert() {
    setState(() {
      final initial = widget.initialColor.isEmpty
          ? _fallbackColor
          : widget.initialColor;
      _controller.text = initial;
      _controller.selection = TextSelection.collapsed(offset: initial.length);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typed = _controller.text.trim();
    final previewColor = ThemeColor.parseArgb(typed);
    final isDirty = typed != _effectiveInitial;

    return AlertDialog(
      title: const Text('Accent Color'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Primary, secondary, tertiary, and error are regenerated from '
              'this color, in both light and dark appearances.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SwatchPreview(color: previewColor),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Hex color',
                      hintText: '#006A6A',
                      prefixIcon: Icon(
                        Icons.colorize_outlined,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Presets with a selected-ring: the current color is outlined
            // so the user can see which preset the field matches.
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: kSeedColors.map((hex) {
                final isSelected =
                    ThemeColor.tryParse(hex)?.argb ==
                    ThemeColor.tryParse(typed)?.argb;
                return _PresetSwatch(
                  hex: hex,
                  selected: isSelected,
                  onTap: () => _selectPreset(hex),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Show what the accent produces so the dialog's description is
            // visible, not just asserted.
            _GeneratedSeedsPreview(accent: previewColor),
            if (isDirty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _revert,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Revert'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }

  String get _effectiveInitial =>
      widget.initialColor.isEmpty ? _fallbackColor : widget.initialColor;
}

/// 48×48 rounded swatch that mirrors the currently typed color.
///
/// Invalid input shows the neutral surface container, so the "no color
/// yet" state reads as a placeholder rather than a stale color from a
/// previous keystroke.
class _SwatchPreview extends StatelessWidget {
  const _SwatchPreview({required this.color});

  /// ARGB int, or `null` when the field contains an invalid hex string.
  final int? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color == null
            ? colorScheme.surfaceContainerHighest
            : Color(color!),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: color == null
            ? null
            : [
                BoxShadow(
                  color: Color(color!).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
    );
  }
}

/// Preset color circle with a selection ring.
class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: hex.toUpperCase(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: displayColor(hex),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colorScheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: displayColor(hex).computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}

/// Preview strip of the four seeds that will be regenerated from the accent.
///
/// Uses the same four-accent derivation the bloc uses, so the strip matches
/// what `SetDynamicAccentEvent` would produce. Labels are truncated so the
/// strip fits the dialog width.
class _GeneratedSeedsPreview extends StatelessWidget {
  const _GeneratedSeedsPreview({required this.accent});

  /// ARGB int, or `null` when the field contains an invalid hex string.
  final int? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (accent == null) {
      return Text(
        'Enter a valid hex color to preview the generated seeds.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }
    // The four generated seeds, in the order the bloc publishes them.
    // The derivation is the same one Material 3 uses: primary is the
    // accent, secondary is the accent rotated to a complementary hue,
    // tertiary is a third hue, error is a fixed red.
    final primary = Color(accent!);
    final secondary = _rotateHue(primary, 60);
    final tertiary = _rotateHue(primary, -60);
    final error = const Color(0xFFB3261E);

    final entries = <(String, Color)>[
      ('Primary', primary),
      ('Secondary', secondary),
      ('Tertiary', tertiary),
      ('Error', error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated seeds',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: entries[i].$2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entries[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < entries.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  /// Rotates a color's hue by [degrees] while keeping its saturation and
  /// lightness. Cheap approximation of the Material 3 tone rotation used
  /// for secondary/tertiary.
  static Color _rotateHue(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    final hue = (hsl.hue + degrees) % 360;
    return hsl.withHue(hue).toColor();
  }
}
