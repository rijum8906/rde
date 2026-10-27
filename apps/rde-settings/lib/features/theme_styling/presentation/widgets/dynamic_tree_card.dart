import 'package:flutter/material.dart';
import 'package:rde_settings/core/theme/domain/entities/dynamic_seeds.dart';
import 'package:rde_settings/core/utils/seed_mode.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/custom_seed_controls.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/seed_summary.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/wallpaper_seed_controls.dart';

// ...state + SeedMode + WallpaperSeedControls + CustomSeedControls + SeedSummary...

class DynamicThemeCard extends StatelessWidget {
  const DynamicThemeCard({
    super.key,
    required this.state,
    required this.seedMode,
    required this.seedRole,
    required this.onSeedModeChanged,
    required this.onSeedRoleChanged,
  });

  final ThemeState state;
  final SeedMode seedMode;
  final DynamicSeedRole seedRole;
  final ValueChanged<SeedMode> onSeedModeChanged;
  final ValueChanged<DynamicSeedRole> onSeedRoleChanged;

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
              'Every palette of rde-dynamic is generated from four seed colors.',
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
              CustomSeedControls(
                state: state,
                seedRole: seedRole,
                onSeedRoleChanged: onSeedRoleChanged,
              ),
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
