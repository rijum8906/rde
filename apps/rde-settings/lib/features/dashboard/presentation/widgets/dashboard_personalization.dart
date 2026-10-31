import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';

/// Quick appearance and accent controls backed by the theme service.
///
/// Both controls go through [ThemeBloc], which writes to `org.rde.Theme` and
/// reloads the catalog, so the selected state always reflects the service.
class DashboardPersonalization extends StatelessWidget {
  const DashboardPersonalization({super.key});

  /// Accent presets optimized for Material 3 ColorScheme generation.
  /// Spaced evenly around the color wheel for maximum visual distinction.
  static const List<Color> _accentColors = [
    // 1. Material Purple (The baseline)
    Color(0xFF6750A4),

    // 2. Deep Indigo (Cool, night-sky blue)
    Color(0xFF3F51B5),

    // 3. Cyan (Bright, tech-focused)
    Color(0xFF0097A7),

    // 4. Emerald Green (Fresh, successful)
    Color(0xFF00695C),

    // 5. Lime / Olive (Earthy, distinct)
    Color(0xFF558B2F),

    // 6. Mustard Yellow (Warm, bright)
    Color(0xFFF57F17),

    // 7. Burnt Orange (Cozy, energetic)
    Color(0xFFD84315),

    // 8. Crimson Red (Bold, aggressive)
    Color(0xFFC62828),

    // 9. Magenta / Rose (Vibrant, playful)
    Color(0xFFAD1457),

    // 10. Deep Violet (Rich, moody)
    Color(0xFF7B1FA2),

    // 11. Slate Blue (Minimalist, calm)
    Color(0xFF546E7A),

    // 12. Warm Grey / Stone (Neutral, professional)
    Color.fromARGB(255, 6, 187, 238),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final themeState = context.watch<ThemeBloc>().state;
    final appearanceMode = themeState.mode;
    final accentSeed = themeState.dynamicSeeds.primary.toUpperCase();

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
              selected: {appearanceMode},
              onSelectionChanged: (newSelection) {
                if (newSelection.isEmpty || themeState.isBusy) return;
                context.read<ThemeBloc>().add(
                  SetAppearanceEvent(newSelection.first),
                );
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
              children: _accentColors.map((color) {
                final isSelected = accentSeed == _hexOf(color);
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (themeState.isBusy) return;
                      context.read<ThemeBloc>().add(
                        SetDynamicAccentEvent(_hexOf(color)),
                      );
                    },
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

  /// Returns [color] as the `#RRGGBB` form the theme service uses for seeds.
  String _hexOf(Color color) {
    final rgb = (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
  }
}
