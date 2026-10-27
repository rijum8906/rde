import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';

// ...bloc + ThemeManifest...

class ThemeRow extends StatelessWidget {
  const ThemeRow({
    super.key,
    required this.info,
    required this.isActive,
    required this.enabled,
  });

  final ThemeManifest info;
  final bool isActive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDynamic = info.name == ThemeManifest.dynamicId;
    final subtitle = isDynamic
        ? 'Generated from the seed colors'
        : (info.description.isNotEmpty ? info.description : info.name);

    return InkWell(
      onTap: enabled && !isActive
          ? () => context.read<ThemeBloc>().add(SelectThemeEvent(info.name))
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDynamic ? Icons.wallpaper : Icons.palette_outlined,
                size: 16,
                color: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    info.author == null
                        ? subtitle
                        : '$subtitle • ${info.author}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: enabled
                    ? () => context.read<ThemeBloc>().add(
                        SelectThemeEvent(info.name),
                      )
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                tooltip: 'Activate',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
