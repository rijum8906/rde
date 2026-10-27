import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/color_input_dialog.dart';

/// Single accent picker that re-seeds every dynamic palette family at once.
///
/// The Bloc derives primary, secondary, tertiary, and error from the picked
/// accent, so this control only has to collect one color.
class AccentColorControls extends StatelessWidget {
  const AccentColorControls({super.key, required this.state});

  /// Current page state; its primary seed is the accent shown here.
  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = state.dynamicSeeds.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick one accent color. The primary, secondary, tertiary, and error '
          'seeds are generated from it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: state.isBusy ? null : () => _editAccent(context, accent),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: displayColor(accent),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accent color',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        accent.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: state.isBusy
                      ? null
                      : () => _editAccent(context, accent),
                  icon: const Icon(Icons.colorize, size: 18),
                  tooltip: 'Choose accent color',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the hex picker and hands the chosen accent to the bloc, which
  /// derives and publishes the four seeds.
  Future<void> _editAccent(BuildContext context, String current) async {
    final color = await showDialog<String>(
      context: context,
      builder: (_) => ColorInputDialog(initialColor: current),
    );
    if (color == null || !context.mounted) return;
    context.read<ThemeBloc>().add(SetDynamicAccentEvent(color));
  }
}
