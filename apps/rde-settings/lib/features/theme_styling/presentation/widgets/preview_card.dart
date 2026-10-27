import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/theme_data_factory.dart';
import 'package:rde_settings/core/utils/preview_roles.dart';
import 'package:rde_settings/core/utils/seed_colors.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/preview_block.dart';

// ...bloc + theme_data_factory + utils + PreviewBlock...

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<AppearanceMode>(
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
          _windowDot(const Color(0xFFFF5F57)),
          const SizedBox(width: 6),
          _windowDot(const Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          _windowDot(const Color(0xFF28C840)),
          const SizedBox(width: 16),
          Text(
            'System Preview',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurfaceVariant,
            ),
          ),
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
          Icon(Icons.menu, color: scheme.primary),
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
          Icon(Icons.search, color: scheme.onSurfaceVariant),
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

  Widget _paletteRoles(ThemeData theme, ColorScheme scheme, dynamic preview) {
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
          spacing: 8,
          runSpacing: 8,
          children: kPreviewRoles.map((role) {
            final hex = preview.colors.hex(role);
            if (hex == null) return const SizedBox.shrink();
            return Tooltip(
              message: '$role  ${hex.toUpperCase()}',
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: displayColor(hex),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
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
