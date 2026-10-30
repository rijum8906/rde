import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

/// Header for the Theme & Styling page.
///
/// Layout mirrors the Bluetooth and Wi-Fi headers: a rounded badge on the
/// left, title + subtitle in the middle, and the page-level action on the
/// right. The action is a labeled `FilledButton.tonalIcon` (not a bare icon
/// button) so the scope of "Reload" is visible without hovering.
class ThemeStylingHeader extends StatelessWidget {
  const ThemeStylingHeader({super.key, required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ThemeBadge(),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme & Styling',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Palettes, themes, and light or dark appearance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              // Only shown while a reload is in flight, so the disabled
              // button has an explanation next to it.
              if (state.isBusy) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    RdeLoadingIndicator(size: 12),
                    const SizedBox(width: 6),
                    Text(
                      'Reloading theme database…',
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
        const SizedBox(width: 16),
        _ReloadButton(isBusy: state.isBusy),
      ],
    );
  }
}

/// 56×56 rounded square holding the palette glyph. Matches `_AdapterBadge`
/// in `bluetooth_adapter_card.dart` and `_WifiBadge` in `wifi_radio_card.dart`
/// so the three page headers read as the same design system.
class _ThemeBadge extends StatelessWidget {
  const _ThemeBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.palette_outlined,
        color: colorScheme.onPrimaryContainer,
        size: 28,
      ),
    );
  }
}

/// Labeled reload button. The label is the point: `Icons.refresh` alone
/// reads as "refresh the page," while "Reload" + the palette context in
/// the title makes it clear this reloads the theme database specifically.
class _ReloadButton extends StatelessWidget {
  const _ReloadButton({required this.isBusy});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: isBusy
          ? null
          : () =>
                context.read<ThemeBloc>().add(const ReloadThemeDatabaseEvent()),
      icon: isBusy
          ? const RdeLoadingIndicator(size: 16)
          : const Icon(Icons.refresh, size: 18),
      label: Text(isBusy ? 'Reloading…' : 'Reload'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}
