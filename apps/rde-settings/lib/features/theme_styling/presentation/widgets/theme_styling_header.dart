import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

// ...bloc imports...

class ThemeStylingHeader extends StatelessWidget {
  const ThemeStylingHeader({super.key, required this.state});
  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme & Styling',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage desktop themes, generate palettes from a seed color, '
                'and switch the light or dark appearance.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: state.isBusy
              ? null
              : () => context.read<ThemeBloc>().add(
                  const ReloadThemeDatabaseEvent(),
                ),
          icon: state.isBusy
              ? const RdeLoadingIndicator(size: 18)
              : const Icon(Icons.refresh),
          tooltip: 'Reload theme database',
        ),
      ],
    );
  }
}
