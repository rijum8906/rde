import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/color_input_dialog.dart';

/// Single accent picker that re-seeds every dynamic palette family at once.
///
/// The Bloc derives primary, secondary, tertiary, and error from the picked
/// accent, so this control only has to collect one color. The generated
/// seeds are shown below the picker as a preview strip, so the user can see
/// what the accent produces before switching to another view.
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
        _AccentRow(
          accent: accent,
          isBusy: state.isBusy,
          onTap: state.isBusy ? null : () => _editAccent(context, accent),
        ),
        if (state.isBusy) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const RdeLoadingIndicator(size: 14),
              const SizedBox(width: 8),
              Text(
                'Applying accent…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 10),
          _ErrorLine(message: state.errorMessage!),
        ],
        const SizedBox(height: 16),
        _GeneratedSeedsRow(seeds: state.dynamicSeeds),
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

/// Tappable row with the current accent swatch, its hex, and a picker icon.
///
/// The whole row is the tap target (one `InkWell`); the trailing icon is
/// decorative and does not have its own gesture. This avoids nested tap
/// targets (which fire twice on some platforms) and gives the row a single,
/// predictable hitbox.
class _AccentRow extends StatelessWidget {
  const _AccentRow({
    required this.accent,
    required this.isBusy,
    required this.onTap,
  });

  final String accent;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: displayColor(accent),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant, width: 2),
              ),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 2),
                  Text(
                    accent.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: RdeLoadingIndicator(size: 18),
              )
            else
              Icon(
                Icons.colorize_outlined,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Preview strip showing the four seeds the accent produces.
///
/// This is the "what will I get?" row. The single accent produces primary,
/// secondary, tertiary, and error; showing them here means the user can see
/// the result of their choice without switching to the live preview.
class _GeneratedSeedsRow extends StatelessWidget {
  const _GeneratedSeedsRow({required this.seeds});

  final dynamic
  seeds; // DynamicSeeds — replace with the concrete type once imported

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The four roles, in the order the Bloc publishes them. Labels match the
    // `DynamicSeedRole` enum in the domain, so a reader can trace each dot
    // back to the seed it represents.
    final entries = <(String, String)>[
      ('Primary', seeds.primary),
      ('Secondary', seeds.secondary),
      ('Tertiary', seeds.tertiary),
      ('Error', seeds.error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated seeds',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              Expanded(
                child: _SeedSwatch(label: entries[i].$1, hex: entries[i].$2),
              ),
              if (i < entries.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({required this.label, required this.hex});

  final String label;
  final String hex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Tooltip(
      message: hex.toUpperCase(),
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: displayColor(hex),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline error line shown when the bloc reports a failure.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: colorScheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
