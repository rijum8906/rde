import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

// ...bloc + state...

class WallpaperSeedControls extends StatelessWidget {
  const WallpaperSeedControls({super.key, required this.state});
  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reads the wallpaper reported by the desktop shell, then keeps its '
          'four most dominant colors.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: state.isBusy
              ? null
              : () => context.read<ThemeBloc>().add(
                  const ExtractWallpaperSeedsEvent(),
                ),
          icon: state.isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wallpaper, size: 18),
          label: const Text('Use wallpaper colors'),
        ),
      ],
    );
  }
}
