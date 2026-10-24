import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus/rde_theme_proxy.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_theme_info.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/create_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/delete_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_source_color.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/mappers/theme_palette_mapper.dart';

/// Seed colors offered as one-tap palette regeneration options.
const List<String> _seedColors = [
  '#6750A4', // Material royal purple
  '#0061A4', // Ocean blue
  '#006E3C', // Emerald
  '#B52700', // Terracotta
  '#7E5700', // Sunny amber
  '#B90063', // Sunset pink
  '#006874', // Deep cyan
  '#4F6310', // Olive
  '#984061', // Plum
  '#3F51B5', // Indigo
  '#E91E63', // Pink
  '#009688', // Teal
];

/// Roles rendered in the palette strip below the live preview.
const List<String> _previewRoles = [
  'primary',
  'primary_container',
  'secondary',
  'tertiary',
  'error',
  'surface_container_high',
  'outline',
];

/// Parses a hex color for display, falling back to the Material seed.
Color _displayColor(String hex) {
  return Color(RdePalette.parseHexColor(hex) ?? 0xFF6750A4);
}

/// Theme & Styling settings backed by the `org.rde.Theme` service.
///
/// The page lists the installed themes, activates them, creates and deletes
/// themes, edits the active theme's seed color, and switches the desktop
/// light/dark appearance. Every action is persisted by the service, and the
/// catalogs it returns are applied to this application's own theme as well.
class ThemeStylingPage extends StatelessWidget {
  const ThemeStylingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Compose the feature the same way the other settings pages do: build the
    // repository locally and hand the use cases to the bloc.
    final repository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    return BlocProvider(
      create: (context) => ThemeBloc(
        loadThemeCatalog: LoadThemeCatalogUseCase(repository),
        setTheme: SetThemeUseCase(repository),
        createTheme: CreateThemeUseCase(repository),
        deleteTheme: DeleteThemeUseCase(repository),
        setSourceColor: SetSourceColorUseCase(repository),
        setColorScheme: SetColorSchemeUseCase(repository),
        reloadThemes: ReloadThemesUseCase(repository),
        watchThemeChanges: WatchThemeChangesUseCase(repository),
      )..add(const ThemeInitEvent()),
      child: const ThemeStylingView(),
    );
  }
}

/// Stateful view so the applied catalog can be tracked by identity.
class ThemeStylingView extends StatefulWidget {
  const ThemeStylingView({super.key});

  @override
  State<ThemeStylingView> createState() => _ThemeStylingViewState();
}

class _ThemeStylingViewState extends State<ThemeStylingView> {
  ThemeCatalog? _appliedCatalog;

  /// Pushes the service palettes into the global app theme.
  void _applyCatalog(BuildContext context, ThemeCatalog catalog) {
    if (identical(_appliedCatalog, catalog)) {
      return;
    }
    _appliedCatalog = catalog;

    context.read<AppThemeBloc>().add(
      ApplySystemPaletteEvent(
        lightScheme: catalog.lightPalette.toColorScheme(),
        darkScheme: catalog.darkPalette.toColorScheme(),
        sourceColorArgb:
            RdePalette.parseHexColor(catalog.sourceColor) ?? 0xFF6750A4,
        isDark: catalog.colorScheme.isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ThemeBloc, ThemeState>(
      listenWhen: (previous, current) =>
          current.catalog != null &&
          !identical(previous.catalog, current.catalog),
      listener: (context, state) => _applyCatalog(context, state.catalog!),
      child: Scaffold(
        body: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            if (!state.hasCatalog) {
              return _buildUnavailableBody(context, state);
            }
            return _buildContent(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildUnavailableBody(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.status != ThemeStatus.failure) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Theme service unavailable',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ??
                  'org.rde.Theme could not be reached on the session bus.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.read<ThemeBloc>().add(const ThemeInitEvent()),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorBanner(context, state.errorMessage!),
          ],
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildActiveThemeCard(context, state),
                        const SizedBox(height: 28),
                        _buildInstalledThemesCard(context, state),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 32),
                  if (!isWide) const SizedBox(height: 32),
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Preview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewCard(context, state),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeState state) {
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
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          tooltip: 'Reload theme database',
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                context.read<ThemeBloc>().add(const DismissThemeErrorEvent()),
            icon: Icon(Icons.close, color: colorScheme.onErrorContainer),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveThemeCard(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalog = state.catalog!;
    final info = catalog.activeTheme;
    final sourceColor = catalog.sourceColor;
    final selectedSeed = RdePalette.parseHexColor(sourceColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active theme identity.
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _displayColor(sourceColor),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info?.displayName ?? catalog.currentTheme,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active theme • ${catalog.currentTheme} • '
                        'org.rde.Theme ${catalog.snapshot.version}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (info != null && info.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                info.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 32),

            // Appearance, global to the desktop.
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switches every themed application on the desktop, and this '
              'settings app with it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildAppearanceOption(
                    context: context,
                    label: 'Light',
                    icon: Icons.light_mode,
                    scheme: RdeColorScheme.light,
                    selected: (catalog.colorScheme == RdeColorScheme.light),
                    enabled: !state.isBusy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAppearanceOption(
                    context: context,
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    scheme: RdeColorScheme.dark,
                    selected: (catalog.colorScheme == RdeColorScheme.dark),
                    enabled: !state.isBusy,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Seed color of the active theme.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seed Color',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _editSeedColor(context, sourceColor),
                  icon: const Icon(Icons.colorize, size: 18),
                  label: const Text('Custom'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Re-seeds the active theme. Both schemes and the toolkit '
              'palettes are regenerated from this color.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: _seedColors.map((hex) {
                final selected = RdePalette.parseHexColor(hex) == selectedSeed;
                return _buildSeedSwatch(
                  context: context,
                  hex: hex,
                  selected: selected,
                  enabled: !state.isBusy,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _displayColor(sourceColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sourceColor.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required RdeColorScheme scheme,
    required bool selected,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: enabled && !selected
          ? () => context.read<ThemeBloc>().add(SetColorSchemeEvent(scheme))
          : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeedSwatch({
    required BuildContext context,
    required String hex,
    required bool selected,
    required bool enabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _displayColor(hex);

    return Tooltip(
      message: hex,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled && !selected
              ? () => context.read<ThemeBloc>().add(SetSourceColorEvent(hex))
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colorScheme.onSurface : Colors.transparent,
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
            child: Center(
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.check,
                  size: 15,
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstalledThemesCard(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalog = state.catalog!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Installed Themes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${catalog.themes.length} theme'
                        '${catalog.themes.length == 1 ? '' : 's'} installed '
                        'by the org.rde.Theme service',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: state.isBusy ? null : () => _createTheme(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Theme'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (catalog.themes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No themes are installed. Create one from a seed color.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(catalog.themes.length, (index) {
                  final info = catalog.themes[index];
                  final isActive = info.name == catalog.currentTheme;

                  return Column(
                    children: [
                      if (index > 0) const Divider(),
                      _buildThemeRow(
                        context: context,
                        info: info,
                        isActive: isActive,
                        enabled: !state.isBusy,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeRow({
    required BuildContext context,
    required RdeThemeInfo info,
    required bool isActive,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                color: _displayColor(info.sourceColor),
                borderRadius: BorderRadius.circular(8),
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
                    info.author.isEmpty
                        ? info.sourceColor.toUpperCase()
                        : '${info.sourceColor.toUpperCase()} • ${info.author}',
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
            else ...[
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
              IconButton(
                onPressed: enabled ? () => _confirmDelete(context, info) : null,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colorScheme.error.withValues(alpha: 0.8),
                ),
                tooltip: 'Delete theme',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final palette = state.previewPalette;
    if (palette == null) {
      return const SizedBox.shrink();
    }

    // The preview renders the service palette for the selected scheme instead
    // of the app theme, so the inactive scheme can be inspected directly.
    final scheme = palette.toColorScheme();
    final isDark = scheme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<RdeColorScheme>(
            segments: const [
              ButtonSegment(
                value: RdeColorScheme.light,
                icon: Icon(Icons.light_mode, size: 16),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: RdeColorScheme.dark,
                icon: Icon(Icons.dark_mode, size: 16),
                label: Text('Dark'),
              ),
            ],
            selected: {state.previewScheme},
            onSelectionChanged: (selection) => context.read<ThemeBloc>().add(
              SetPreviewSchemeEvent(selection.first),
            ),
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
              // Mock window title bar.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(23),
                    topRight: Radius.circular(23),
                  ),
                ),
                child: Row(
                  children: [
                    _buildWindowDot(const Color(0xFFFF5F57)),
                    const SizedBox(width: 6),
                    _buildWindowDot(const Color(0xFFFFBD2E)),
                    const SizedBox(width: 6),
                    _buildWindowDot(const Color(0xFF28C840)),
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
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mock top app bar.
                    Container(
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
                    ),
                    const SizedBox(height: 14),

                    // Mock tonal containers.
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewBlock(
                            theme: theme,
                            scheme: scheme,
                            background: scheme.primaryContainer,
                            foreground: scheme.onPrimaryContainer,
                            title: 'Primary',
                            body: 'Seeded tonal colors',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPreviewBlock(
                            theme: theme,
                            scheme: scheme,
                            background: scheme.secondaryContainer,
                            foreground: scheme.onSecondaryContainer,
                            title: 'Secondary',
                            body: 'Supporting accents',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Mock settings row with a switch.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
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
                          Icon(
                            Icons.toggle_on,
                            size: 30,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Buttons.
                    Row(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                    ),
                    const SizedBox(height: 18),

                    // Palette roles straight from GetPalette.
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
                      children: _previewRoles.map((role) {
                        final hex = palette.hex(role);
                        if (hex == null) {
                          return const SizedBox.shrink();
                        }
                        return Tooltip(
                          message: '$role  ${hex.toUpperCase()}',
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _displayColor(hex),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildPreviewBlock({
    required ThemeData theme,
    required ColorScheme scheme,
    required Color background,
    required Color foreground,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: foreground.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSeedColor(BuildContext context, String current) async {
    final color = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ColorInputDialog(initialColor: current),
    );

    if (color == null || !context.mounted) {
      return;
    }
    context.read<ThemeBloc>().add(SetSourceColorEvent(color));
  }

  Future<void> _createTheme(BuildContext context) async {
    final request = await showDialog<_NewThemeRequest>(
      context: context,
      builder: (dialogContext) => const _CreateThemeDialog(),
    );

    if (request == null || !context.mounted) {
      return;
    }
    context.read<ThemeBloc>().add(
      CreateThemeEvent(name: request.name, sourceColor: request.sourceColor),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RdeThemeInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete theme?'),
        content: Text(
          '"${info.displayName}" will be removed from the theme database. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<ThemeBloc>().add(DeleteThemeEvent(info.name));
  }
}

/// Result of the create-theme dialog.
class _NewThemeRequest {
  const _NewThemeRequest({required this.name, required this.sourceColor});

  final String name;
  final String sourceColor;
}

/// Validates a theme identifier the same way the service does.
bool _isValidThemeName(String value) {
  return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value);
}

/// Dialog that creates a new theme from a name and a seed color.
class _CreateThemeDialog extends StatefulWidget {
  const _CreateThemeDialog();

  @override
  State<_CreateThemeDialog> createState() => _CreateThemeDialogState();
}

class _CreateThemeDialogState extends State<_CreateThemeDialog> {
  final _nameController = TextEditingController();
  final _colorController = TextEditingController(text: '#006A6A');
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final color = _colorController.text.trim();

    setState(() {
      // Step 1: Reject names the service would reject.
      if (!_isValidThemeName(name)) {
        _error =
            'Use letters, digits, "-", "_" or "." (max 64 characters), '
            'starting with a letter or digit.';
        return;
      }

      // Step 2: Require a parseable hex color.
      if (RdePalette.parseHexColor(color) == null) {
        _error = 'Enter a hex color such as #006A6A or #06A.';
        return;
      }

      _error = null;
    });

    if (_error != null) {
      return;
    }
    Navigator.of(context).pop(_NewThemeRequest(name: name, sourceColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewColor = RdePalette.parseHexColor(_colorController.text.trim());

    return AlertDialog(
      title: const Text('New Theme'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The theme is generated from a single seed color and installed '
              'next to the existing themes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Theme name',
                hintText: 'ocean',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: previewColor == null
                        ? colorScheme.surfaceContainerHighest
                        : Color(previewColor),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Seed color',
                      hintText: '#006A6A',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _seedColors.map((hex) {
                return InkWell(
                  onTap: () => setState(() {
                    _colorController.text = hex;
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _displayColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            _colorController.text.trim().toUpperCase() ==
                                hex.toUpperCase()
                            ? colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// Dialog that edits the seed color of the active theme.
class _ColorInputDialog extends StatefulWidget {
  const _ColorInputDialog({required this.initialColor});

  final String initialColor;

  @override
  State<_ColorInputDialog> createState() => _ColorInputDialogState();
}

class _ColorInputDialogState extends State<_ColorInputDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialColor.isEmpty ? '#6750A4' : widget.initialColor,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final color = _controller.text.trim();

    if (RdePalette.parseHexColor(color) == null) {
      setState(() => _error = 'Enter a hex color such as #006A6A or #06A.');
      return;
    }

    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewColor = RdePalette.parseHexColor(_controller.text.trim());

    return AlertDialog(
      title: const Text('Custom Seed Color'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Every palette role of the active theme is regenerated from this '
              'color, in both light and dark appearances.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: previewColor == null
                        ? colorScheme.surfaceContainerHighest
                        : Color(previewColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Hex color',
                      hintText: '#006A6A',
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _seedColors.map((hex) {
                return InkWell(
                  onTap: () => setState(() {
                    _controller.text = hex;
                    _error = null;
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _displayColor(hex),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }
}
