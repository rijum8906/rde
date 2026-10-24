import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_theme_info.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_service_snapshot.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/create_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/delete_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_source_color.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';

/// Builds a theme bloc wired to an arbitrary repository.
ThemeBloc buildThemeBloc(ThemeRepository repository) {
  return ThemeBloc(
    loadThemeCatalog: LoadThemeCatalogUseCase(repository),
    setTheme: SetThemeUseCase(repository),
    createTheme: CreateThemeUseCase(repository),
    deleteTheme: DeleteThemeUseCase(repository),
    setSourceColor: SetSourceColorUseCase(repository),
    setColorScheme: SetColorSchemeUseCase(repository),
    reloadThemes: ReloadThemesUseCase(repository),
    watchThemeChanges: WatchThemeChangesUseCase(repository),
  );
}

/// In-memory stand-in for the `org.rde.Theme` repository.
class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository();

  final Map<String, String> sourceColors = {
    'default': '#6DD6DA',
    'ocean': '#006A6A',
  };
  final List<String> installedThemes = ['default', 'ocean'];
  final List<String> calls = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  String currentTheme = 'default';
  RdeColorScheme colorScheme = RdeColorScheme.dark;
  bool failLoad = false;
  int loadCalls = 0;

  /// Emits a service property change.
  void notifyChanged() => _changes.add(null);

  /// Releases the signal stream.
  Future<void> dispose() => _changes.close();

  RdePalette _palette(String theme, RdeColorScheme scheme) {
    return RdePalette(
      theme: theme,
      scheme: scheme,
      roles: {
        'primary': sourceColors[theme]!,
        'on_primary': '#FFFFFF',
        'surface': scheme.isDark ? '#0E1414' : '#FAFDFC',
        'on_surface': scheme.isDark ? '#E0E3E2' : '#191C1C',
      },
    );
  }

  ThemeCatalog _catalog() {
    return ThemeCatalog(
      snapshot: ThemeServiceSnapshot(
        version: '0.1.0',
        currentTheme: currentTheme,
        installedThemes: List.of(installedThemes),
        colorScheme: colorScheme,
        sourceColor: sourceColors[currentTheme]!,
      ),
      themes: installedThemes
          .map(
            (name) => RdeThemeInfo(
              name: name,
              displayName: name[0].toUpperCase() + name.substring(1),
              description: '$name theme',
              sourceColor: sourceColors[name]!,
            ),
          )
          .toList(),
      lightPalette: _palette(currentTheme, RdeColorScheme.light),
      darkPalette: _palette(currentTheme, RdeColorScheme.dark),
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
  Future<Either<Failure, void>> setTheme(String theme) async {
    calls.add('setTheme:$theme');
    if (!installedThemes.contains(theme)) {
      return Left(Failure('Theme "$theme" is not installed.'));
    }
    currentTheme = theme;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> createTheme(
    String name,
    String sourceColor,
  ) async {
    calls.add('createTheme:$name:$sourceColor');
    if (installedThemes.contains(name)) {
      return Left(Failure('Theme "$name" already exists.'));
    }
    installedThemes.add(name);
    sourceColors[name] = sourceColor;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteTheme(String theme) async {
    calls.add('deleteTheme:$theme');
    if (theme == currentTheme) {
      return Left(Failure('The active theme cannot be deleted.'));
    }
    installedThemes.remove(theme);
    sourceColors.remove(theme);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setSourceColor(String sourceColor) async {
    calls.add('setSourceColor:$sourceColor');
    sourceColors[currentTheme] = sourceColor;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setColorScheme(RdeColorScheme scheme) async {
    calls.add('setColorScheme:${scheme.dbusValue}');
    colorScheme = scheme;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> reload() async {
    calls.add('reload');
    return const Right(null);
  }

  @override
  Stream<void> watchThemeChanges() => _changes.stream;
}
