import 'package:flutter/foundation.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus/rde_theme_proxy.dart';
import 'package:rde_settings/features/theme_styling/data/datasources/dbus_theme_datasource.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/domain/repositories/theme_repository_impl.dart';
import 'package:rde_settings/features/theme_styling/domain/use_cases/load_theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/presentation/mappers/theme_palette_mapper.dart';

/// Applies the desktop's `org.rde.Theme` palette to the settings app at start.
///
/// Called once from `main()` before the first frame settles. When the theme
/// service is not running the app keeps its built-in seed color, so a missing
/// service never blocks startup.
///
/// # Parameters
/// - [appThemeBloc]: global bloc wrapping the `MaterialApp` theme
Future<void> syncSystemTheme(AppThemeBloc appThemeBloc) async {
  try {
    // Step 1: Compose the D-Bus client for the one-off read.
    final repository = ThemeRepositoryImpl(
      DbusThemeDatasource(RdeThemeProxy()),
    );

    // Step 2: Load the catalog and remember it outside the closure.
    ThemeCatalog? catalog;
    final result = await LoadThemeCatalogUseCase(repository)();
    result.fold(
      (failure) => debugPrint(
        'Unable to load the org.rde.Theme palette at startup: '
        '${failure.message}',
      ),
      (value) => catalog = value,
    );

    if (catalog == null) {
      return;
    }

    // Step 3: Hand both generated schemes to the app theme bloc.
    appThemeBloc.add(
      ApplySystemPaletteEvent(
        lightScheme: catalog!.lightPalette.toColorScheme(),
        darkScheme: catalog!.darkPalette.toColorScheme(),
        sourceColorArgb:
            RdePalette.parseHexColor(catalog!.sourceColor) ?? 0xFF6750A4,
        isDark: catalog!.colorScheme.isDark,
      ),
    );
  } catch (error) {
    // A missing or unresponsive theme service must never block startup.
    debugPrint('Unable to apply the org.rde.Theme palette at startup: $error');
  }
}
