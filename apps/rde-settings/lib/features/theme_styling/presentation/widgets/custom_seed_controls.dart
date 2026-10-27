import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/domain/entities/dynamic_seeds.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_color.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/color_input_dialog.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/seed_swatch.dart';

// ...bloc + DynamicSeedRole + ThemeColor + utils + SeedSwatch + ColorInputDialog...

class CustomSeedControls extends StatelessWidget {
  const CustomSeedControls({
    super.key,
    required this.state,
    required this.seedRole,
    required this.onSeedRoleChanged,
  });

  final ThemeState state;
  final DynamicSeedRole seedRole;
  final ValueChanged<DynamicSeedRole> onSeedRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = state.dynamicSeeds.seedFor(seedRole);
    final selectedSeed = ThemeColor.tryParse(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in DynamicSeedRole.values)
              ChoiceChip(
                label: Text(role.label),
                selected: seedRole == role,
                showCheckmark: false,
                onSelected: state.isBusy
                    ? null
                    : (_) => onSeedRoleChanged(role),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: displayColor(current),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${seedRole.label} seed',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              current.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => _editSeedColor(context, seedRole, current),
              icon: const Icon(Icons.colorize, size: 16),
              label: const Text('Custom'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: kSeedColors.map((hex) {
            final selected =
                ThemeColor.tryParse(hex)?.argb == selectedSeed?.argb;
            return SeedSwatch(
              role: seedRole,
              hex: hex,
              selected: selected,
              enabled: !state.isBusy,
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _editSeedColor(
    BuildContext context,
    DynamicSeedRole role,
    String current,
  ) async {
    final color = await showDialog<String>(
      context: context,
      builder: (_) => ColorInputDialog(initialColor: current),
    );
    if (color == null || !context.mounted) return;
    context.read<ThemeBloc>().add(SetDynamicSeedEvent(role, color));
  }
}
