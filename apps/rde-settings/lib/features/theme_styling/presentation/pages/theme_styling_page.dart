import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/data/datasources/dbus/rde_theme_proxy.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/seed_source.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_color.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/core/theme/theme_data_factory.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/preview_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';

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
  return Color(ThemeColor.parseArgb(hex) ?? 0xFF6750A4);
}

/// Theme & Styling settings backed by the `org.rde.Theme` service.
///
/// The page lists the installed themes, activates them, edits the inputs of
/// the built-in dynamic theme, and switches the desktop light/dark appearance.
/// Themes themselves are author-owned manifests on disk, so this page never
/// creates or deletes them. Every action is persisted by the service, and this
/// application's own theme follows the payload the service publishes.
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
        previewTheme: PreviewThemeUseCase(repository),
        setTheme: SetThemeUseCase(repository),
        setMode: SetModeUseCase(repository),
        updateDynamicTheme: UpdateDynamicThemeUseCase(repository),
        reloadThemes: ReloadThemesUseCase(repository),
        watchThemeChanges: WatchThemeChangesUseCase(repository),
      )..add(const ThemeInitEvent()),
      child: const ThemeStylingView(),
    );
  }
}

/// Renders the catalog published by [ThemeBloc].
///
/// The application theme itself follows `org.rde.Theme` through the system
/// theme sync, so this view only renders the service state.
class ThemeStylingView extends StatefulWidget {
  const ThemeStylingView({super.key});

  @override
  State<ThemeStylingView> createState() => _ThemeStylingViewState();
}

class _ThemeStylingViewState extends State<ThemeStylingView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          if (!state.hasCatalog) {
            return _buildUnavailableBody(context, state);
          }
          return _buildContent(context, state);
        },
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
                        _buildDynamicThemeCard(context, state),
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
    final info = state.activeTheme;
    final sourceColor = catalog.resolved.colors.primary.value;

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
                    mode: AppearanceMode.light,
                    selected: (catalog.mode == AppearanceMode.light),
                    enabled: !state.isBusy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAppearanceOption(
                    context: context,
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    mode: AppearanceMode.dark,
                    selected: (catalog.mode == AppearanceMode.dark),
                    enabled: !state.isBusy,
                  ),
                ),
              ],
            ),
            if (info != null && (info.author != null || info.license != null))
              ...[
                const Divider(height: 32),
                Row(
                  children: [
                    if (info.author != null)
                      Expanded(
                        child: Text(
                          'Author • ${info.author}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (info.license != null)
                      Text(
                        'License • ${info.license}',
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
    );
  }

  Widget _buildAppearanceOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required AppearanceMode mode,
    required bool selected,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: enabled && !selected
          ? () => context.read<ThemeBloc>().add(SetAppearanceEvent(mode))
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
              ? () => context.read<ThemeBloc>().add(SetDynamicSeedEvent(hex))
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
            Column(
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
                  '${catalog.themes.length == 1 ? '' : 's'} available to '
                  'org.rde.Theme, including the built-in dynamic theme',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (catalog.themes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No themes are installed. Add a theme manifest to the '
                  'themes directory and reload.',
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
    required ThemeManifest info,
    required bool isActive,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDynamic = info.name == ThemeManifest.dynamicId;
    final subtitle = isDynamic
        ? 'Wallpaper-derived colors'
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
                    info.author == null ? subtitle : '$subtitle • ${info.author}',
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final preview = state.previewTheme;
    if (preview == null) {
      return const SizedBox.shrink();
    }

    // The preview renders the payload the service resolves for the selected
    // appearance instead of the app theme, so the inactive appearance can be
    // inspected without switching the desktop preference.
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
            onSelectionChanged: (selection) => context.read<ThemeBloc>().add(
              SetPreviewModeEvent(selection.first),
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

                    // Color roles of the payload returned by Preview.
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
                        final hex = preview.colors.hex(role);
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

  /// Renders the inputs of the built-in `rde-dynamic` theme.
  ///
  /// The service stores inputs only and recomputes the palette from them, so
  /// this card edits the seed source, the fixed seed color, and the wallpaper
  /// path instead of any resolved color.
  Widget _buildDynamicThemeCard(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalog = state.catalog!;
    final seedSource = catalog.dynamicSeedSource;
    final selectedSeed = ThemeColor.tryParse(catalog.dynamicSeed);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dynamic Theme',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'org.rde.Theme regenerates the built-in rde-dynamic palette from '
              'the desktop wallpaper or a fixed seed color.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!catalog.isDynamicActive) ...[
              const SizedBox(height: 8),
              Text(
                'Activate rde-dynamic to apply these inputs to the desktop.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<SeedSource>(
              segments: const [
                ButtonSegment(
                  value: SeedSource.wallpaper,
                  icon: Icon(Icons.wallpaper, size: 16),
                  label: Text('Wallpaper'),
                ),
                ButtonSegment(
                  value: SeedSource.fixed,
                  icon: Icon(Icons.colorize, size: 16),
                  label: Text('Fixed color'),
                ),
              ],
              selected: {seedSource},
              onSelectionChanged: state.isBusy
                  ? null
                  : (selection) => context.read<ThemeBloc>().add(
                      SetDynamicSeedSourceEvent(selection.first),
                    ),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 18),

            // Wallpaper the seed color is derived from.
            Row(
              children: [
                Expanded(
                  child: Text(
                    catalog.dynamicWallpaper.isEmpty
                        ? 'No wallpaper recorded yet'
                        : catalog.dynamicWallpaper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _editWallpaper(context, catalog.dynamicWallpaper),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Wallpaper'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Explicit seed color used by the fixed source.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seed Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => _editSeedColor(context, catalog.dynamicSeed),
                  icon: const Icon(Icons.colorize, size: 18),
                  label: const Text('Custom'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: _seedColors.map((hex) {
                final selected =
                    ThemeColor.tryParse(hex)?.argb == selectedSeed?.argb;
                return _buildSeedSwatch(
                  context: context,
                  hex: hex,
                  selected: selected,
                  enabled: !state.isBusy,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: catalog.dynamicSeed.isEmpty
                        ? colorScheme.surfaceContainerHighest
                        : _displayColor(catalog.dynamicSeed),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  catalog.dynamicSeed.isEmpty
                      ? 'No fixed seed color'
                      : catalog.dynamicSeed.toUpperCase(),
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

  Future<void> _editSeedColor(BuildContext context, String current) async {
    final color = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ColorInputDialog(initialColor: current),
    );

    if (color == null || !context.mounted) {
      return;
    }
    context.read<ThemeBloc>().add(SetDynamicSeedEvent(color));
  }

  Future<void> _editWallpaper(BuildContext context, String current) async {
    final wallpaper = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _WallpaperInputDialog(initialPath: current),
    );

    if (wallpaper == null || !context.mounted) {
      return;
    }
    context.read<ThemeBloc>().add(SetDynamicWallpaperEvent(wallpaper));
  }
}

/// Dialog that points the built-in dynamic theme at an explicit wallpaper.
class _WallpaperInputDialog extends StatefulWidget {
  const _WallpaperInputDialog({required this.initialPath});

  final String initialPath;

  @override
  State<_WallpaperInputDialog> createState() => _WallpaperInputDialogState();
}

class _WallpaperInputDialogState extends State<_WallpaperInputDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final path = _controller.text.trim();
    if (!path.startsWith('/')) {
      setState(
        () => _error = 'Enter an absolute path, such as /home/you/wall.png.',
      );
      return;
    }

    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Wallpaper'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'org.rde.Theme derives the dynamic palette from this image.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Wallpaper path',
                hintText: '/home/you/Pictures/wallpaper.png',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
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

    if (ThemeColor.parseArgb(color) == null) {
      setState(() => _error = 'Enter a hex color such as #006A6A or #06A.');
      return;
    }

    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewColor = ThemeColor.parseArgb(_controller.text.trim());

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
