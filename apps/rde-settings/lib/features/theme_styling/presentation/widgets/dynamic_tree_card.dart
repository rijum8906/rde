import 'package:flutter/material.dart';
import 'package:rde_settings/core/utils/seed_mode.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/accent_color_controls.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/seed_summary.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/wallpaper_seed_controls.dart';

// ...state + SeedMode + WallpaperSeedControls + AccentColorControls + SeedSummary...

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
    final catalog = state.catalog!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Colors',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Every palette of rde-dynamic is generated from one accent color.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            if (seedMode == SeedMode.dynamic)
              WallpaperSeedControls(state: state)
            else
              AccentColorControls(state: state),
            const SizedBox(height: 16),
            SeedSummary(seeds: state.dynamicSeeds),
            if (!catalog.isDynamicActive) ...[
              const SizedBox(height: 12),
              Text(
                'Activate rde-dynamic to apply these colors to the desktop.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
