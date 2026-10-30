import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/extract_wallpaper_seeds.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/preview_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';

/// Builds a theme bloc wired to an arbitrary repository.
ThemeBloc buildThemeBloc(ThemeRepository repository) {
  return ThemeBloc(
    loadThemeCatalog: LoadThemeCatalogUseCase(repository),
    previewTheme: PreviewThemeUseCase(repository),
    setTheme: SetThemeUseCase(repository),
    setMode: SetModeUseCase(repository),
    updateDynamicTheme: UpdateDynamicThemeUseCase(repository),
    extractWallpaperSeeds: ExtractWallpaperSeedsUseCase(repository),
    reloadThemes: ReloadThemesUseCase(repository),
    watchThemeChanges: WatchThemeChangesUseCase(repository),
  );
}

/// Builds a resolved payload with the given primary color and appearance.
ResolvedTheme sampleResolvedTheme({
  required String themeId,
  required String primary,
  required AppearanceMode mode,
}) {
  // The role order matches the service's ColorRoles struct; only the roles the
  // settings UI reads are given meaningful values.
  final hexes = List<String>.filled(ColorRoles.roleCount, '#808080');
  hexes[0] = primary;
  hexes[1] = '#FFFFFF';
  hexes[18] = mode.isDark ? '#101413' : '#FAFDFC';
  hexes[19] = mode.isDark ? '#E0E3E2' : '#191C1C';
  hexes[25] = mode.isDark ? '#1A1F1E' : '#E8ECEB';

  return ResolvedTheme(
    schemaVersion: 1,
    themeId: themeId,
    variant: mode.isDark ? 'dark' : 'light',
    kind: VariantKind.staticFile,
    colors: ColorRoles.fromHexList(hexes),
    typography: const ThemeTypography(
      fontFamily: 'Cantarell, Inter, sans-serif',
    ),
    shape: const ThemeShape(
      radiusExtraSmall: 4,
      radiusSmall: 8,
      radiusMedium: 12,
      radiusLarge: 16,
      radiusExtraLarge: 28,
    ),
    motion: const ThemeMotion(
      durationShortMs: 150,
      durationMediumMs: 300,
      durationLongMs: 500,
      curveStandard: 'cubic-bezier(0.2, 0.0, 0.0, 1.0)',
      curveEmphasized: 'cubic-bezier(0.2, 0.0, 0.0, 1.25)',
    ),
  );
}

/// In-memory stand-in for the `org.rde.Theme` repository.
class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository();

  final Map<String, String> primaryColors = {
    'default': '#6DD6DA',
    'ocean': '#006A6A',
    ThemeManifest.dynamicId: '#6750A4',
  };

  final List<String> calls = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  final Map<String, ThemeManifest> manifests = {
    'default': const ThemeManifest(
      schemaVersion: 1,
      name: 'default',
      displayName: 'Default',
      description: 'Built-in RDE theme',
      version: '1.0.0',
      defaultVariant: 'dark',
      variants: [
        ThemeVariant(
          id: 'light',
          mode: AppearanceMode.light,
          contrast: ContrastLevel.normal,
          filePath: 'light.json',
        ),
        ThemeVariant(
          id: 'dark',
          mode: AppearanceMode.dark,
          contrast: ContrastLevel.normal,
          filePath: 'dark.json',
        ),
      ],
    ),
    'ocean': const ThemeManifest(
      schemaVersion: 1,
      name: 'ocean',
      displayName: 'Ocean',
      description: 'ocean theme',
      version: '1.0.0',
      defaultVariant: 'dark',
      variants: [
        ThemeVariant(
          id: 'dark',
          mode: AppearanceMode.dark,
          contrast: ContrastLevel.normal,
          filePath: 'dark.json',
        ),
      ],
    ),
    ThemeManifest.dynamicId: const ThemeManifest(
      schemaVersion: 1,
      name: ThemeManifest.dynamicId,
      displayName: 'Dynamic',
      description: 'Wallpaper-derived colors',
      version: '1.0.0',
      defaultVariant: 'dark',
      variants: [
        ThemeVariant(
          id: 'dark',
          mode: AppearanceMode.dark,
          contrast: ContrastLevel.normal,
          filePath: 'rde-dynamic/dark.json',
        ),
      ],
    ),
  };

  String currentTheme = 'default';
  AppearanceMode mode = AppearanceMode.dark;
  DynamicSeeds dynamicSeeds = const DynamicSeeds(
    primary: '#6DD6DA',
    secondary: '#6750A4',
    tertiary: '#B52700',
    error: '#BA1A1A',
  );
  DynamicSeeds? wallpaperSeeds;
  bool failWallpaper = false;
  bool failLoad = false;
  int loadCalls = 0;

  /// Emits a service change.
  void notifyChanged() => _changes.add(null);

  /// Releases the signal stream.
  Future<void> dispose() => _changes.close();

  /// Returns the payload the service would publish for [theme] and [mode].
  ResolvedTheme resolvedFor(String theme, AppearanceMode mode) {
    return sampleResolvedTheme(
      themeId: theme,
      primary: primaryColors[theme] ?? '#6DD6DA',
      mode: mode,
    );
  }

  ThemeCatalog _catalog() {
    return ThemeCatalog(
      snapshot: ThemeSnapshot(
        version: 1,
        activeTheme: currentTheme == ThemeManifest.dynamicId
            ? ''
            : currentTheme,
        mode: mode,
        availableThemes: manifests.keys
            .where((name) => name != ThemeManifest.dynamicId)
            .toList(),
        generation: loadCalls,
      ),
      themes: manifests.values.toList(),
      resolved: resolvedFor(currentTheme, mode),
    );
  }

  @override
  Future<Either<Failure, ThemeCatalog>> loadCatalog() async {
    loadCalls++;
    if (failLoad) {
      return Left(Failure('The theme service is offline.'));
    }
    return Right(_catalog());
  }

  @override
  Future<Either<Failure, ResolvedTheme>> preview(
    String theme,
    AppearanceMode mode, [
    ContrastLevel contrast = ContrastLevel.normal,
  ]) async {
    calls.add('preview:$theme:${mode.dbusValue}');
    return Right(resolvedFor(theme, mode));
  }

  @override
  Future<Either<Failure, void>> setTheme(String theme) async {
    calls.add('setTheme:$theme');
    if (!manifests.containsKey(theme)) {
      return Left(Failure('Theme "$theme" is not installed.'));
    }
    currentTheme = theme;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setMode(AppearanceMode mode) async {
    calls.add('setMode:${mode.dbusValue}');
    this.mode = mode;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateDynamicTheme({
    String primary = '',
    String secondary = '',
    String tertiary = '',
    String error = '',
  }) async {
    calls.add('updateDynamicTheme:$primary:$secondary:$tertiary:$error');
    dynamicSeeds = DynamicSeeds(
      primary: primary.isEmpty ? dynamicSeeds.primary : primary,
      secondary: secondary.isEmpty ? dynamicSeeds.secondary : secondary,
      tertiary: tertiary.isEmpty ? dynamicSeeds.tertiary : tertiary,
      error: error.isEmpty ? dynamicSeeds.error : error,
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, DynamicSeeds>> seedsFromWallpaper() async {
    calls.add('seedsFromWallpaper');
    if (failWallpaper) {
      return Left(Failure('The wallpaper could not be read.'));
    }
    return Right(wallpaperSeeds ?? dynamicSeeds);
  }

  @override
  Future<Either<Failure, void>> reload() async {
    calls.add('reload');
    return const Right(null);
  }

  @override
  Stream<void> watchThemeChanges() => _changes.stream;
}
