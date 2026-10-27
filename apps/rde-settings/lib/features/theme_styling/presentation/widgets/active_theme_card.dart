import 'package:flutter/material.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/appearance.dart';

// ...state/entities + AppearanceOption + utils imports...

class ActiveThemeCard extends StatelessWidget {
  const ActiveThemeCard({super.key, required this.state});
  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalog = state.catalog!;
    final info = state.activeTheme;
    final sourceColor = catalog.resolved.colors.primary.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Theme',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _identityRow(theme, colorScheme, catalog, info, sourceColor),
            if (info != null && info.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                info.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switches every themed application on the desktop, and this '
              'settings app with it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppearanceOption(
                    label: 'Light',
                    icon: Icons.light_mode,
                    mode: AppearanceMode.light,
                    selected: catalog.mode == AppearanceMode.light,
                    enabled: !state.isBusy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppearanceOption(
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    mode: AppearanceMode.dark,
                    selected: catalog.mode == AppearanceMode.dark,
                    enabled: !state.isBusy,
                  ),
                ),
              ],
            ),
            if (info != null &&
                (info.author != null || info.license != null)) ...[
              const Divider(height: 32),
              Row(
                children: [
                  if (info.author != null)
                    Expanded(
                      child: Text(
                        'Author • ${info.author}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (info.license != null)
                    Text(
                      'License • ${info.license}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _identityRow(
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic catalog,
    dynamic info,
    String sourceColor,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: displayColor(sourceColor),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info?.displayName ?? catalog.currentTheme,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Active theme • ${catalog.currentTheme} • '
                'org.rde.Theme ${catalog.snapshot.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
