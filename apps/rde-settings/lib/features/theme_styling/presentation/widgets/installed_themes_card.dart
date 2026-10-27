import 'package:flutter/material.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/theme_row.dart';

// ...state + ThemeRow...

class InstalledThemesCard extends StatelessWidget {
  const InstalledThemesCard({super.key, required this.state});
  final ThemeState state;

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
              'Installed Themes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${catalog.themes.length} theme'
              '${catalog.themes.length == 1 ? '' : 's'} available',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (catalog.themes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No themes are installed. Add a theme manifest to the '
                  'themes directory and reload.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(catalog.themes.length, (index) {
                  final info = catalog.themes[index];
                  final isActive = info.name == catalog.currentTheme;
                  return Column(
                    children: [
                      if (index > 0) const Divider(),
                      ThemeRow(
                        info: info,
                        isActive: isActive,
                        enabled: !state.isBusy,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
