import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/navigation/router.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_bloc.dart';
import 'package:rde_settings/core/theme/bloc/app_theme_state.dart';

// Global bloc for dynamic UI customization
final appThemeBloc = AppThemeBloc();

void main() {
  runApp(const SettingsApp());
}

class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key});

  ThemeData _createTheme(Color accentColor, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );

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
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Settings',
            theme: _createTheme(state.accentColor, Brightness.light),
            darkTheme: _createTheme(state.accentColor, Brightness.dark),
            themeMode: state.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
