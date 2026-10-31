import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:rde_settings/features/dashboard/presentation/bloc/dashboard_state.dart';

class DashboardPersonalization extends StatelessWidget {
  const DashboardPersonalization({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Color> accentColors = [
      const Color(0xFF6750A4), // Purple
      const Color(0xFF0061A4), // Ocean Blue
      const Color(0xFF006E3C), // Emerald
      const Color(0xFFB52700), // Terracotta
      const Color(0xFF7E5700), // Sunny Amber
      const Color(0xFFB90063), // Sunset Pink
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Personalization',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Theme Mode',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppearanceMode>(
              segments: const [
                ButtonSegment(
                  value: AppearanceMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppearanceMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {state.appearanceMode},
              onSelectionChanged: (newSelection) {
                if (newSelection.isNotEmpty) {
                  context.read<DashboardBloc>().add(
                    ChangeThemeAppearanceEvent(newSelection.first),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Accent Color Seed',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: accentColors.map((color) {
                final isSelected =
                    state.accentColor.toARGB32() == color.toARGB32();
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.read<DashboardBloc>().add(
                      ChangeAccentColorEvent(color),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
