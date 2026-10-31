import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/navigation/router.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_state.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/core/theme/system_theme_sync.dart';
import 'package:rde_settings/core/theme/app_theme_builder.dart'; // <-- Import builder

// Global bloc for dynamic UI customization
final appThemeBloc = AppThemeBloc();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Adopt the theme the service cached during its last publication, so
  // the first frame already renders the desktop appearance instead of a flash
  // of the fallback seed.
  final cached = const RdeThemeCache().read();
  if (cached != null) {
    final applied = appThemeBloc.stream.firstWhere(
      (state) => state.resolvedTheme == cached,
    );
    appThemeBloc.add(
      ApplyResolvedThemeEvent(
        resolved: cached,
        // The payload carries no brightness, so read it from the surface role.
        mode: AppearanceMode.fromSurface(cached.colors.surface),
      ),
    );
    await applied;
  }

  // Step 2: Listen for service publications and reconcile the cached payload
  // with the service; later changes are read with GetResolvedTheme after the
  // ThemeChanged signal.
  unawaited(syncSystemTheme(appThemeBloc));

  runApp(const SettingsApp());
}

class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: appThemeBloc,
      child: BlocBuilder<AppThemeBloc, AppThemeState>(
        builder: (context, state) {
          final resolvedTheme = state.theme;

          // Use the builder to generate themes from the ColorScheme
          final lightTheme =
              resolvedTheme ??
              AppThemeBuilder.build(
                ColorScheme.fromSeed(
                  seedColor: state.accentColor,
                  brightness: Brightness.light,
                ),
              );

          final darkTheme =
              resolvedTheme ??
              AppThemeBuilder.build(
                ColorScheme.fromSeed(
                  seedColor: state.accentColor,
                  brightness: Brightness.dark,
                ),
              );

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Settings',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: state.appearanceMode == AppearanceMode.light
                ? ThemeMode.light
                : ThemeMode.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
