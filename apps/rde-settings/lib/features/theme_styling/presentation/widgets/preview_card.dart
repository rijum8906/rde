import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/core/utils/preview_roles.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/preview_block.dart';

/// Live preview of the resolved theme.
///
/// The card renders the *other* appearance (light when the desktop is dark,
/// dark when the desktop is light) by default, so the user can inspect the
/// mode they aren't currently using without switching the whole desktop.
/// The mock window is intentionally made from theme roles — every color in
/// it comes from the resolved palette, so a change in the theme shows up in
/// the mock immediately.
class PreviewCard extends StatelessWidget {
  const PreviewCard({super.key, required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = state.previewTheme;
    if (preview == null) return const SizedBox.shrink();

    final scheme = colorSchemeFromResolved(preview, mode: state.previewMode);
    final isDark = state.previewMode.isDark;
    final desktopMode = state.catalog?.mode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Live Preview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SegmentedButton<AppearanceMode>(
              segments: const [
                ButtonSegment(
                  value: AppearanceMode.light,
                  icon: Icon(Icons.light_mode, size: 16),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: AppearanceMode.dark,
                  icon: Icon(Icons.dark_mode, size: 16),
                  label: Text('Dark'),
                ),
              ],
              selected: {state.previewMode},
              onSelectionChanged: (s) =>
                  context.read<ThemeBloc>().add(SetPreviewModeEvent(s.first)),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // The "Preview only" caption is the load-bearing honesty of this
        // card: switching preview mode does not change the desktop. Without
        // it, users assume the toggle is a live theme switch.
        Text(
          desktopMode == null
              ? 'Preview only — the desktop uses its current mode.'
              : 'Preview only — the desktop stays in ${desktopMode.name} mode.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleBar(theme, scheme),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _mockAppBar(theme, scheme),
                    const SizedBox(height: 14),
                    _mockTonalRow(theme, scheme),
                    const SizedBox(height: 14),
                    _mockSettingsRow(theme, scheme),
                    const SizedBox(height: 14),
                    _surfaceLadder(theme, scheme),
                    const SizedBox(height: 14),
                    _outlineAndError(theme, scheme),
                    const SizedBox(height: 14),
                    _mockButtons(theme, scheme),
                    const SizedBox(height: 18),
                    _paletteRoles(theme, scheme, preview),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Window chrome. The three dots use the theme's own `error`, `tertiary`,
  /// and `primary` roles instead of macOS's fixed traffic lights, so the
  /// "system" chrome reflects the theme being previewed.
  Widget _titleBar(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(23),
          topRight: Radius.circular(23),
        ),
      ),
      child: Row(
        children: [
          _windowDot(scheme.error),
          const SizedBox(width: 6),
          _windowDot(scheme.tertiary),
          const SizedBox(width: 6),
          _windowDot(scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'System Preview',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          // A real window chrome affordance: the close button.
          Icon(Icons.close, size: 14, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _mockAppBar(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.menu, color: scheme.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'My Application',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
          Icon(Icons.search, color: scheme.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }

  Widget _mockTonalRow(ThemeData theme, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: PreviewBlock(
            theme: theme,
            background: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
            title: 'Primary',
            body: 'Seeded tonal colors',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PreviewBlock(
            theme: theme,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            title: 'Secondary',
            body: 'Supporting accents',
          ),
        ),
      ],
    );
  }

  Widget _mockSettingsRow(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.palette, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adaptive Styling',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
          Icon(Icons.toggle_on, size: 30, color: scheme.primary),
        ],
      ),
    );
  }

  /// The surface elevation ladder: five steps from the lowest (most
  /// recessive) to the highest (most prominent). This is the clearest way
  /// to show what "dark mode" actually changes — the relative lightness of
  /// the surface roles, not just one background color.
  Widget _surfaceLadder(ThemeData theme, ColorScheme scheme) {
    final steps = <String, Color>{
      'lowest': scheme.surfaceContainerLowest,
      'low': scheme.surfaceContainerLow,
      'default': scheme.surfaceContainer,
      'high': scheme.surfaceContainerHigh,
      'highest': scheme.surfaceContainerHighest,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Surface elevation',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final entry in steps.entries) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: entry.value,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.key != steps.keys.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  /// Outline + error sample. Two roles the mock otherwise never shows:
  /// `outline` (the neutral border) and `error` (the destructive action).
  Widget _outlineAndError(ThemeData theme, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.outline),
                const SizedBox(width: 8),
                Text(
                  'Outlined',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockButtons(ThemeData theme, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Cancel',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Confirm',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Palette strip with role labels below each swatch. Labels are truncated
  /// to fit, so `surface_container_high` becomes `surface_…_high` rather
  /// than overflowing the swatch. The tooltip keeps the full name.
  Widget _paletteRoles(
    ThemeData theme,
    ColorScheme scheme,
    ResolvedTheme preview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Palette roles',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kPreviewRoles.map((role) {
            final hex = preview.colors.hex(role);
            if (hex == null) return const SizedBox.shrink();
            final label = role.replaceAll('_', ' ');
            return Tooltip(
              message: '$role\n${hex.toUpperCase()}',
              child: SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: displayColor(hex),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _windowDot(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
