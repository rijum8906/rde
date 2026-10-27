import 'package:flutter/material.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_color.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';

/// Dialog that edits a seed color as a hex string.
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
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewColor = ThemeColor.parseArgb(_controller.text.trim());

    return AlertDialog(
      title: const Text('Custom Seed Color'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This family is regenerated from the color, in both light and '
              'dark appearances. The other three families keep their seeds.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSwatchPreview(previewColor, colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Hex color',
                      hintText: '#006A6A',
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: kSeedColors.map((hex) {
                return InkWell(
                  onTap: () => _selectPreset(hex),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: displayColor(hex),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
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

  /// Rounded square that mirrors the currently typed color.
  ///
  /// Shows the neutral surface container while the input is invalid, so the
  /// empty / malformed state reads as "no color yet" rather than a stale one.
  Widget _buildSwatchPreview(int? previewColor, ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: previewColor == null
            ? colorScheme.surfaceContainerHighest
            : Color(previewColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
    );
  }
}
