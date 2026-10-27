import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/theme/data/datasources/dbus/rde_theme_proxy.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/extract_wallpaper_seeds.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/preview_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/reload_themes.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_mode.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/set_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/update_dynamic_theme.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/watch_theme_changes.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_event.dart';
import 'package:rde_settings/features/theme_styling/presentation/views/theme_styling_view.dart';

class ThemeStylingPage extends StatelessWidget {
  const ThemeStylingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    return BlocProvider(
      create: (_) => ThemeBloc(
        loadThemeCatalog: LoadThemeCatalogUseCase(repository),
        previewTheme: PreviewThemeUseCase(repository),
        setTheme: SetThemeUseCase(repository),
        setMode: SetModeUseCase(repository),
        updateDynamicTheme: UpdateDynamicThemeUseCase(repository),
        extractWallpaperSeeds: ExtractWallpaperSeedsUseCase(repository),
        reloadThemes: ReloadThemesUseCase(repository),
        watchThemeChanges: WatchThemeChangesUseCase(repository),
      )..add(const ThemeInitEvent()),
      child: const ThemeStylingView(),
    );
  }
}
