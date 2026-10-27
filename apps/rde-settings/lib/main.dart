import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/navigation/router.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_event.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_state.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/system_theme_sync.dart';
import 'package:rde_settings/core/theme/theme_cache.dart';

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

  ThemeData _createTheme(ColorScheme colorScheme) {
    final brightness = colorScheme.brightness;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'Roboto',
        'Segoe UI',
        '-apple-system',
        'Helvetica Neue',
        'sans-serif',
      ],
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.secondaryContainer,
        thumbColor: colorScheme.primary,
        trackHeight: 6,
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle: TextStyle(color: colorScheme.onPrimary),
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: appThemeBloc,
      child: BlocBuilder<AppThemeBloc, AppThemeState>(
        builder: (context, state) {
          // The resolved desktop theme covers both slots: the appearance it was
          // resolved for decides which slot Flutter renders. Until the service
          // answers, a local seed keeps the app usable.
          final resolvedTheme = state.theme;
          final lightTheme =
              resolvedTheme ??
              _createTheme(
                ColorScheme.fromSeed(
                  seedColor: state.accentColor,
                  brightness: Brightness.light,
                ),
              );
          final darkTheme =
              resolvedTheme ??
              _createTheme(
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
            themeMode: state.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
