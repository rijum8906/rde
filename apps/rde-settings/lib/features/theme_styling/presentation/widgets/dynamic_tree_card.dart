import 'package:flutter/material.dart';
import 'package:rde_settings/core/utils/seed_mode.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/accent_color_controls.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/wallpaper_seed_controls.dart';

/// Card that edits the inputs of the built-in `rde-dynamic` theme.
///
/// The card is laid out top-to-bottom as: header → mode selector → the
/// mode-specific control well → the seed summary → an optional call-to-action
/// when the dynamic theme isn't currently active. It uses the same card
/// vocabulary as [ActiveThemeCard] and [PreviewCard]: a leading icon in the
/// header, a `Divider(height: 32)` between sections, and a tinted "well"
/// for the control block so it doesn't float on the card surface.
class DynamicThemeCard extends StatelessWidget {
  const DynamicThemeCard({
    super.key,
    required this.state,
    required this.seedMode,
    required this.onSeedModeChanged,
  });

  final ThemeState state;
  final SeedMode seedMode;
  final ValueChanged<SeedMode> onSeedModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(theme, colorScheme),
            const Divider(height: 32),
            Text(
              'Source',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<SeedMode>(
              segments: [
                for (final mode in SeedMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(mode.icon, size: 16),
                    label: Text(mode.label),
                  ),
              ],
              selected: {seedMode},
              onSelectionChanged: (s) => onSeedModeChanged(s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 8),
            Text(
              seedMode.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // Control "well": the mode-specific block gets its own surface
            // so it reads as a sub-section rather than as a card-level
            // control. Both `WallpaperSeedControls` and `AccentColorControls`
            // are designed to live inside a card body, so the well is just
            // a tinted container that groups them with the mode selector.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: seedMode == SeedMode.dynamic
                  ? WallpaperSeedControls(state: state)
                  : AccentColorControls(state: state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.color_lens_outlined, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Colors',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: 'Every palette of ',
                  children: [
                    TextSpan(
                      text: 'rde-dynamic',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const TextSpan(
                      text: ' is generated from a single accent color.',
                    ),
                  ],
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
